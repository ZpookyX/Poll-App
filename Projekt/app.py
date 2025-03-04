import os
from flask import Flask, request, jsonify, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import ForeignKey, Table, Column, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from flask_dance.contrib.google import make_google_blueprint, google
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required

app = Flask(__name__)
app.secret_key = "your_secret_key"  # Change this in production

# Either server database is run on Azure or it is run on SQLite locally
if "AZURE_POSTGRESQL_CONNECTIONSTRING" in os.environ:
    conn = os.environ["AZURE_POSTGRESQL_CONNECTIONSTRING"]
    values = dict(x.split("=") for x in conn.split(' '))
    user = values['user']
    host = values['host']
    database = values['dbname']
    db_uri = f'postgresql+psycopg2://{user}:@{host}/{database}'
    app.config['SQLALCHEMY_DATABASE_URI'] = db_uri
    debug_flag = False
else:  # when running locally: use sqlite
    db_path = os.path.join(os.path.dirname(__file__), 'lab3.db')
    db_uri = f'sqlite:///{db_path}'
    app.config['SQLALCHEMY_DATABASE_URI'] = db_uri
    debug_flag = True

db = SQLAlchemy()
db.init_app(app)

login_manager = LoginManager()
login_manager.init_app(app)

# OAuth Blueprint for Google login
google_bp = make_google_blueprint(
    client_id="YOUR_GOOGLE_CLIENT_ID",
    client_secret="YOUR_GOOGLE_CLIENT_SECRET",
    redirect_to="google_login",
    scope=["profile", "email"]
)
app.register_blueprint(google_bp, url_prefix="/login")

# Association table for many-to-many relationship
MessageReads = Table(
    "messagereads",
    db.metadata,
    Column("user_id", Integer, ForeignKey("user.id"), primary_key=True),
    Column("message_id", Integer, ForeignKey("message.id"), primary_key=True)
)

class User(db.Model, UserMixin):
    __tablename__ = "user"

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(unique=True, nullable=False)
    google_id: Mapped[str] = mapped_column(unique=True, nullable=True)  # Added for Google login

    read_messages: Mapped[list["Message"]] = relationship(
        "Message", secondary=MessageReads, back_populates="read_by_users"
    )

    def __init__(self, username, google_id=None):
        self.username = username
        self.google_id = google_id

class Message(db.Model):
    __tablename__ = "message"

    id: Mapped[int] = mapped_column(primary_key=True)
    message: Mapped[str] = mapped_column(nullable=False)

    read_by_users: Mapped[list["User"]] = relationship(
        "User",
        secondary=MessageReads,
        back_populates="read_messages"
    )

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Google OAuth Login
@app.route("/google_login")
def google_login():
    if not google.authorized:
        return redirect(url_for("google.login"))

    resp = google.get("/oauth2/v1/userinfo")
    if resp.ok:
        user_info = resp.json()
        user = User.query.filter_by(google_id=user_info["id"]).first()

        if not user:
            user = User(username=user_info["name"], google_id=user_info["id"])
            db.session.add(user)
            db.session.commit()

        login_user(user)
        return jsonify({"message": "Logged in!", "user": {"username": user.username, "id": user.id}})

    return jsonify({"message": "Google login failed"}), 401

# Logout Route
@app.route("/logout", methods=["POST"])
@login_required
def logout():
    logout_user()
    return jsonify({'message': "Logged out successfully"}), 200

# Save a message
@app.route('/messages', methods=['POST'])
def save_message():
    data = request.get_json()
    if not data or 'message' not in data or len(data['message']) > 140:
        return jsonify({'message': 'Invalid message'}), 400

    new_message = Message(message=data['message'])
    db.session.add(new_message)
    db.session.commit()

    return jsonify({'id': new_message.id}), 200

# Retrieve a message with a unique ID
@app.route('/messages/<message_id>', methods=['GET'])
def retrieve_message(message_id):
    message = Message.query.get(message_id)
    if message:
        return jsonify({
            'id': message.id,
            'message': message.message,
            'readBy': [user.username for user in message.read_by_users]
        }), 200
    return jsonify({'message': "Message not found"}), 404

# Mark a message as read
@app.route('/messages/<message_id>/read/<user_id>', methods=['POST'])
def mark_message_as_read(message_id, user_id):
    message = Message.query.get(message_id)
    user = User.query.get(user_id)

    if not message or not user:
        return jsonify({'message': 'Message or User not found'}), 404

    if message not in user.read_messages:
        user.read_messages.append(message)
        db.session.commit()
    return jsonify({'message': 'Marked as read'}), 200

# Retrieve all messages
@app.route('/messages', methods=['GET'])
def all_messages():
    messages_all = Message.query.all()
    return jsonify([{'id': message.id, 'message': message.message} for message in messages_all]), 200

# Retrieve all unread messages by a unique user
@app.route('/messages/unread/<user_id>', methods=['GET'])
def all_messages_read_by_user(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'message': 'User not found'}), 404

    unread_messages = [m for m in Message.query.all() if m not in user.read_messages]
    return jsonify([{'id': m.id, 'message': m.message} for m in unread_messages]), 200

# Error handling
@app.errorhandler(404)
def page_not_found(error):
    return jsonify({'message': 'Not Found'}), 404

@app.errorhandler(400)
def bad_request(error):
    return jsonify({'message': 'Bad Request'}), 400

@app.errorhandler(500)
def internal_server_error(error):
    return jsonify({'message': 'Internal Server Error'}), 500


def create_app():
    return app

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True)
