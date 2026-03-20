// API エンドポイント（環境に応じて変更）
// 本番環境では実際のApp Runner URLを設定する
// ローカルも本番環境もパスの最後にスラッシュを入れたほうがよい
const API_URL = window.location.hostname === 'localhost'
    ? 'http://localhost:8080/api/todos/'
    : 'https://xxxxxxxxxxx.ap-northeast-1.awsapprunner.com/api/todos/';

// 状態管理
let todos = [];
let currentFilter = 'all';

// DOM要素
const todoTitleInput = document.getElementById('todoTitle');
const todoDescriptionInput = document.getElementById('todoDescription');
const addBtn = document.getElementById('addBtn');
const todoList = document.getElementById('todoList');
const loading = document.getElementById('loading');
const emptyState = document.getElementById('emptyState');
const todoCount = document.getElementById('todoCount');
const filterButtons = document.querySelectorAll('.filter-btn');

// 初期化
document.addEventListener('DOMContentLoaded', () => {
    loadTodos();
    setupEventListeners();
});

// イベントリスナー設定
function setupEventListeners() {
    addBtn.addEventListener('click', addTodo);
    todoTitleInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') addTodo();
    });

    filterButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            filterButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentFilter = btn.dataset.filter;
            renderTodos();
        });
    });
}

// Todoを読み込む
async function loadTodos() {
    try {
        showLoading(true);
        const response = await fetch(API_URL);
        if (!response.ok) throw new Error('Failed to fetch todos');

        todos = await response.json();
        renderTodos();
    } catch (error) {
        console.error('Error loading todos:', error);
        showError('タスクの読み込みに失敗しました');
    } finally {
        showLoading(false);
    }
}

// Todoを追加
async function addTodo() {
    const title = todoTitleInput.value.trim();
    const description = todoDescriptionInput.value.trim();

    if (!title) {
        alert('タスクのタイトルを入力してください');
        return;
    }

    try {
        const response = await fetch(API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                title,
                description: description || null,
                completed: false
            })
        });

        if (!response.ok) throw new Error('Failed to create todo');

        const newTodo = await response.json();
        todos.unshift(newTodo); // 先頭に追加

        todoTitleInput.value = '';
        todoDescriptionInput.value = '';
        todoTitleInput.focus();

        renderTodos();
    } catch (error) {
        console.error('Error adding todo:', error);
        showError('タスクの追加に失敗しました');
    }
}

// Todoを削除
async function deleteTodo(id) {
    if (!confirm('このタスクを削除しますか？')) return;

    try {
        const response = await fetch(`${API_URL}${id}`, {
            method: 'DELETE'
        });

        if (!response.ok) throw new Error('Failed to delete todo');

        todos = todos.filter(todo => todo.id !== id);
        renderTodos();
    } catch (error) {
        console.error('Error deleting todo:', error);
        showError('タスクの削除に失敗しました');
    }
}

// Todoの完了状態をトグル
async function toggleTodo(id) {
    try {
        const response = await fetch(`${API_URL}${id}/toggle`, {
            method: 'PATCH'
        });

        if (!response.ok) throw new Error('Failed to toggle todo');

        const updatedTodo = await response.json();
        todos = todos.map(todo =>
            todo.id === id ? updatedTodo : todo
        );

        renderTodos();
    } catch (error) {
        console.error('Error toggling todo:', error);
        showError('タスクの更新に失敗しました');
    }
}

// Todoをレンダリング
function renderTodos() {
    const filteredTodos = getFilteredTodos();

    if (filteredTodos.length === 0) {
        todoList.innerHTML = '';
        emptyState.style.display = 'block';
        updateStats();
        return;
    }

    emptyState.style.display = 'none';

    todoList.innerHTML = filteredTodos.map(todo => `
        <div class="todo-item ${todo.completed ? 'completed' : ''}" data-id="${todo.id}">
            <div class="todo-content">
                <input
                    type="checkbox"
                    class="todo-checkbox"
                    ${todo.completed ? 'checked' : ''}
                    onchange="toggleTodo(${todo.id})"
                >
                <div class="todo-text">
                    <div class="todo-title">${escapeHtml(todo.title)}</div>
                    ${todo.description ? `<div class="todo-description">${escapeHtml(todo.description)}</div>` : ''}
                    <div class="todo-meta">
                        <span class="todo-date">${formatDate(todo.created_at)}</span>
                    </div>
                </div>
            </div>
            <button class="btn btn-delete" onclick="deleteTodo(${todo.id})">
                🗑️
            </button>
        </div>
    `).join('');

    updateStats();
}

// フィルタリング
function getFilteredTodos() {
    switch (currentFilter) {
        case 'active':
            return todos.filter(todo => !todo.completed);
        case 'completed':
            return todos.filter(todo => todo.completed);
        default:
            return todos;
    }
}

// 統計を更新
function updateStats() {
    const activeTodos = todos.filter(todo => !todo.completed);
    todoCount.textContent = activeTodos.length;
}

// ローディング表示
function showLoading(show) {
    loading.style.display = show ? 'block' : 'none';
}

// エラー表示
function showError(message) {
    alert(message);
}

// 日付フォーマット
function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now - date;
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days === 0) {
        const hours = Math.floor(diff / (1000 * 60 * 60));
        if (hours === 0) {
            const minutes = Math.floor(diff / (1000 * 60));
            return minutes === 0 ? 'たった今' : `${minutes}分前`;
        }
        return `${hours}時間前`;
    } else if (days === 1) {
        return '昨日';
    } else if (days < 7) {
        return `${days}日前`;
    } else {
        return date.toLocaleDateString('ja-JP');
    }
}

// HTMLエスケープ
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
