import pytest
from app import create_app, db, User, Message

# Create a test client for the app
@pytest.fixture
def app():
    app = create_app()
    app.config[
        'SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'  # In-memory database
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['WTF_CSRF_ENABLED'] = False  # Disable CSRF for testing
    app.config['SECRET_KEY'] = 'test_secret_key'

    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()


# Create a test client for making requests
@pytest.fixture
def client(app):
    return app.test_client()


# Create a user for testing
@pytest.fixture
def user(app):
    user = User(username="testuser", google_id="google_test_id")
    db.session.add(user)
    db.session.commit()
    return user


# Test saving a message
def test_save_message(client):
    message_data = {'message': 'This is a test message'}
    response = client.post('/messages', json=message_data)
    assert response.status_code == 200
    assert b'id' in response.data  # Check if message id is returned


# Test retrieving a message by ID
def test_retrieve_message(client):
    message_data = {'message': 'This is a test message'}
    response = client.post('/messages', json=message_data)
    message_id = response.json['id']

    # Retrieve the message by ID
    response = client.get(f'/messages/{message_id}')
    assert response.status_code == 200
    assert b'This is a test message' in response.data


# Test retrieving a non-existent message
def test_retrieve_non_existent_message(client):
    response = client.get('/messages/9999')
    assert response.status_code == 404
    assert b'Message not found' in response.data


# Test marking a message as read
def test_mark_message_as_read(client, user):
    # Create a message
    message_data = {'message': 'This is a test message'}
    response = client.post('/messages', json=message_data)
    message_id = response.json['id']

    # Mark the message as read
    response = client.post(f'/messages/{message_id}/read/{user.id}')
    assert response.status_code == 200
    assert b'Marked as read' in response.data


# Test retrieving all messages
def test_all_messages(client):
    # Create some messages
    for msg in ['First message', 'Second message', 'Third message']:
        client.post('/messages', json={'message': msg})

    response = client.get('/messages')
    assert response.status_code == 200
    assert len(response.json) == 3  # Should return 3 messages


# Test retrieving unread messages for a user
def test_unread_messages(client, user):
    # Create some messages
    for msg in ['First message', 'Second message', 'Third message']:
        client.post('/messages', json={'message': msg})

    # Mark one message as read
    message_id = 1  # Assuming first message gets ID 1
    client.post(f'/messages/{message_id}/read/{user.id}')

    response = client.get(f'/messages/unread/{user.id}')
    assert response.status_code == 200
    assert len(response.json) == 2  # Should return unread messages (2)
