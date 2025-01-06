import flask
from flask import *
from sqlalchemy import *
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.exc import SQLAlchemyError
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from functools import wraps
from datetime import datetime, timedelta, UTC
import os

Base = declarative_base()

class Friend(Base):
    __tablename__ = 'is_friend_with'

    id = Column(Integer, primary_key=True, autoincrement=True, nullable=False)
    user = Column(Integer, nullable=False)
    friend = Column(Integer, nullable=False)

    def __repr__(self):
        return f"<Friend(id={self.id}, user={self.user}, friend={self.friend})>"
    
    def to_dict(self):
        return {
            'id': self.id,
            'user': self.user,
            'friend': self.friend,
        }
    
class User(Base):
    __tablename__ = 'user'

    id = Column(Integer, primary_key=True, autoincrement=True, nullable=False)
    username = Column(String, nullable=False, unique=True)
    email = Column(String, nullable=False)
    password = Column(String, nullable=False)
    imgURL = Column(String, nullable=False)

    def __repr__(self):
        return f"<User(id={self.id}, username={self.username}, email={self.email}, password={self.password}, imgURL={self.imgURL})>"
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'password': self.password,
            'imgURL': self.imgURL,
        }
    
class Position(Base):
    __tablename__ = 'position'

    user = Column(Integer, primary_key=True, nullable=False)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)

    def __repr__(self):
        return f"<Position(user={self.user}, lat={self.lat}, lng={self.lng})>"
    
    def to_dict(self):
        return {
            'user': self.user,
            'lat': self.lat,
            'lng': self.lng,
        }
    
class FriendRequest(Base):
    __tablename__ = 'friend_requests'

    id = Column(Integer, primary_key=True, autoincrement=True, nullable=False)
    from_user = Column(Integer, ForeignKey('user.id'), nullable=False)
    to_user = Column(Integer, ForeignKey('user.id'), nullable=False)
    created_at = Column(DateTime, default=datetime.now(UTC), nullable=False)
    status = Column(String, default='pending', nullable=False)  # pending, accepted, rejected

    def __repr__(self):
        return f"<FriendRequest(id={self.id}, from={self.from_user}, to={self.to_user}, status={self.status})>"
    
    def to_dict(self):
        return {
            'id': self.id,
            'from_user': self.from_user,
            'to_user': self.to_user,
            'created_at': self.created_at.isoformat(),
            'status': self.status,
        }

engine = create_engine('sqlite:///staynear.db')

# Tabellen erstellen
Base.metadata.create_all(engine)

# Session-Factory erstellen
Session = sessionmaker(bind=engine)

app = flask.Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'testsecret')

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'message': 'Token fehlt!'}), 401
        
        try:
            token = token.split(" ")[1]  # "Bearer <token>" Format
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=["HS256"])
            session = Session()
            try:
                current_user = session.query(User).filter_by(id=data['user_id']).first()
                if not current_user:
                    return jsonify({'message': 'Benutzer nicht gefunden!'}), 401
                
                result = f(current_user, session, *args, **kwargs)
                session.commit()
                return result
            except Exception as e:
                session.rollback()
                raise e
            finally:
                session.close()
                
        except jwt.ExpiredSignatureError:
            return jsonify({'message': 'Token ist abgelaufen!'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'message': 'Token ist ungültig!'}), 401
            
    return decorated

# Auth
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    
    if not all(k in data for k in ('username', 'email', 'password')):
        return jsonify({'message': 'Fehlende Daten!'}), 400
        
    session = Session()
    try:
        # Prüfe erst ob Username bereits existiert
        if session.query(User).filter_by(username=data['username']).first():
            return jsonify({'message': 'Benutzername bereits vergeben!'}), 409
            
        # Dann prüfe ob Email bereits existiert
        if session.query(User).filter_by(email=data['email']).first():
            return jsonify({'message': 'Email bereits registriert!'}), 409
            
        hashed_password = generate_password_hash(data['password'])
        default_img = "https://i.ibb.co/wWXyqpt/test.png"  # Bild anpassen
        
        new_user = User(
            username=data['username'],
            email=data['email'],
            password=hashed_password,
            imgURL=default_img
        )
        
        session.add(new_user)
        session.commit()
        return jsonify({'message': 'Nutzer erfolgreich registriert!'}), 201
    except SQLAlchemyError as e:
        session.rollback()
        return jsonify({'message': f'Datenbankfehler: {str(e)}'}), 500
    finally:
        session.close()

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    
    if not all(k in data for k in ('email', 'password')):
        return jsonify({'message': 'Fehlende Daten!'}), 400
        
    session = Session()
    try:
        user = session.query(User).filter_by(email=data['email']).first()
        
        if not user or not check_password_hash(user.password, data['password']):
            return jsonify({'message': 'Falsche Zugangsdaten!'}), 401
            
        token = jwt.encode({
            'user_id': user.id,
            'exp': datetime.now(UTC) + timedelta(days=7)
        }, app.config['SECRET_KEY'])
        
        return jsonify({
            'token': token,
            'user': user.to_dict()
        })
    finally:
        session.close()

@app.route('/logout', methods=['POST'])
@token_required
def logout(current_user, session):
    return jsonify({'message': 'Erfolgreich ausgeloggt!'})

# User
@app.route('/users/search/<username>', methods=['GET'])
@token_required
def search_users(current_user, session, username):
    try:
        # Search for users whose username contains the search term (case-insensitive)
        users = session.query(User).filter(
            User.username.ilike(f'%{username}%')
        ).all()
        
        # Get current user's friends to check friendship status
        friend_ids = {friend.friend for friend in 
            session.query(Friend).filter_by(user=current_user.id).all()}
        
        # Format response with friendship status
        results = []
        for user in users:
            if user.id != current_user.id:  # Don't include current user
                results.append({
                    'id': user.id,
                    'username': user.username,
                    'imgURL': user.imgURL,
                    'isFriend': user.id in friend_ids
                })
        
        return jsonify(results)
    except SQLAlchemyError as e:
        session.rollback()
        return jsonify({'message': str(e)}), 500

# Profile
@app.route('/profile/image', methods=['PUT'])
@token_required
def update_profile_image(current_user, session):
    if 'image' not in request.files:
        return jsonify({'message': 'Kein Bild hochgeladen!'}), 400
        
    file = request.files['image']
    if file.filename == '':
        return jsonify({'message': 'Keine Datei ausgewählt!'}), 400
        
    filename = f"user_{current_user.id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
    file.save(os.path.join('uploads', filename))
    
    user = session.get(User, current_user.id)
    user.imgURL = filename
    
    return jsonify({'message': 'Profilbild aktualisiert!', 'imgURL': filename})

# Friends
@app.route('/friends', methods=['GET'])
@token_required
def get_user_friends(current_user, session):
    friends = session.query(Friend, User).join(
        User, User.id == Friend.friend
    ).filter(Friend.user == current_user.id).all()
    
    return jsonify([{
        **friend.User.to_dict(),
        'friend_id': friend.Friend.id
    } for friend in friends])

@app.route('/friends/all', methods=['GET'])
@token_required
def get_all_friends(current_user, session):
    try:
        friends = session.query(Friend, User).join(
            User, User.id == Friend.friend
        ).filter(Friend.user == current_user.id).all()
        
        return jsonify([{
            'id': friend.User.id,
            'username': friend.User.username,
            'imgURL': friend.User.imgURL
        } for friend in friends])
    except SQLAlchemyError as e:
        session.rollback()
        return jsonify({'message': str(e)}), 500

@app.route('/friends/add/<int:friend_id>', methods=['POST'])
@token_required
def add_friend(current_user, session, friend_id):
    if current_user.id == friend_id:
        return jsonify({'message': 'Du kannst dich nicht selbst als Freund hinzufügen!'}), 400
        
    if not session.get(User, friend_id):
        return jsonify({'message': 'Benutzer nicht gefunden!'}), 404
            
    # Prüfe ob eine der Freundschaftsrichtungen bereits existiert
    existing_friendship1 = session.query(Friend).filter_by(user=current_user.id, friend=friend_id).first()
    existing_friendship2 = session.query(Friend).filter_by(user=friend_id, friend=current_user.id).first()
            
    if existing_friendship1 or existing_friendship2:
        return jsonify({'message': 'Bereits als Freund hinzugefügt!'}), 409
            
    # Füge beide Richtungen der Freundschaft hinzu
    friendship1 = Friend(user=current_user.id, friend=friend_id)
    friendship2 = Friend(user=friend_id, friend=current_user.id)
    session.add(friendship1)
    session.add(friendship2)
    
    return jsonify({'message': 'Freund erfolgreich hinzugefügt!'})

@app.route('/friends/remove/<int:friend_id>', methods=['DELETE'])
@token_required
def remove_friend(current_user, session, friend_id):
    # Finde beide Richtungen der Freundschaft
    friendship1 = session.query(Friend).filter_by(
        user=current_user.id, 
        friend=friend_id
    ).first()
    
    friendship2 = session.query(Friend).filter_by(
        user=friend_id,
        friend=current_user.id
    ).first()
    
    if not friendship1 and not friendship2:
        return jsonify({'message': 'Freundschaft nicht gefunden!'}), 404
    
    # Lösche beide Richtungen wenn sie existieren    
    if friendship1:
        session.delete(friendship1)
    if friendship2:
        session.delete(friendship2)
    
    return jsonify({'message': 'Freund erfolgreich entfernt!'})

@app.route('/friends/request/<int:user_id>', methods=['POST'])
@token_required
def send_friend_request(current_user, session, user_id):
    if current_user.id == user_id:
        return jsonify({'message': 'Du kannst dir selbst keine Freundschaftsanfrage senden!'}), 400
        
    # Prüfe ob der Zieluser existiert
    target_user = session.query(User).get(user_id)
    if not target_user:
        return jsonify({'message': 'Benutzer nicht gefunden!'}), 404
    
    try:
        # Prüfe ob bereits eine Freundschaft besteht
        existing_friendship = session.query(Friend).filter(
            ((Friend.user == current_user.id) & (Friend.friend == user_id)) |
            ((Friend.user == user_id) & (Friend.friend == current_user.id))
        ).first()
        
        if existing_friendship:
            return jsonify({'message': 'Ihr seid bereits befreundet!'}), 409
        
        # Prüfe ob bereits eine ausstehende Anfrage existiert
        existing_request = session.query(FriendRequest).filter(
            ((FriendRequest.from_user == current_user.id) & (FriendRequest.to_user == user_id) |
            (FriendRequest.from_user == user_id) & (FriendRequest.to_user == current_user.id)) &
            (FriendRequest.status == 'pending')
        ).first()
        
        if existing_request:
            return jsonify({'message': 'Es gibt bereits eine ausstehende Freundschaftsanfrage!'}), 409
            
        # Erstelle neue Freundschaftsanfrage
        new_request = FriendRequest(
            from_user=current_user.id,
            to_user=user_id,
            status='pending'
        )
        
        session.add(new_request)
        session.commit()
        
        return jsonify({'message': 'Freundschaftsanfrage erfolgreich gesendet!'})
        
    except SQLAlchemyError as e:
        session.rollback()
        return jsonify({'message': f'Datenbankfehler: {str(e)}'}), 500
    
@app.route('/friends/requests/pending', methods=['GET'])
@token_required
def get_pending_friend_requests(current_user, session):
    try:
        # Hole alle ausstehenden Anfragen für den aktuellen User
        pending_requests = session.query(FriendRequest).join(
            User, User.id == FriendRequest.from_user
        ).filter(
            FriendRequest.to_user == current_user.id,
            FriendRequest.status == 'pending'
        ).all()
        
        # Formatiere die Antwort
        requests_data = []
        for request in pending_requests:
            from_user = session.query(User).get(request.from_user)
            requests_data.append({
                'id': request.id,
                'from_user': request.from_user,
                'from_username': from_user.username,
                'from_user_image': from_user.imgURL,
                'created_at': request.created_at.strftime('%d.%m.%Y %H:%M'),
                'status': request.status
            })
            
        return jsonify(requests_data)
    except SQLAlchemyError as e:
        session.rollback()
        return jsonify({'message': str(e)}), 500

@app.route('/friends/requests/<int:request_id>/accept', methods=['POST'])
@token_required
def accept_friend_request(current_user, session, request_id):
    try:
        friend_request = session.query(FriendRequest).get(request_id)
        
        if not friend_request:
            return jsonify({'message': 'Anfrage nicht gefunden'}), 404
            
        if friend_request.to_user != current_user.id:
            return jsonify({'message': 'Nicht autorisiert'}), 403
            
        if friend_request.status != 'pending':
            return jsonify({'message': 'Anfrage wurde bereits bearbeitet'}), 400
            
        # Akzeptiere die Anfrage
        friend_request.status = 'accepted'
        
        # Erstelle die Freundschaft in beide Richtungen
        friendship1 = Friend(user=current_user.id, friend=friend_request.from_user)
        friendship2 = Friend(user=friend_request.from_user, friend=current_user.id)
        
        session.add(friendship1)
        session.add(friendship2)
        
        return jsonify({'message': 'Freundschaftsanfrage akzeptiert'})
    except SQLAlchemyError as e:
        session.rollback()
        return jsonify({'message': str(e)}), 500

@app.route('/friends/requests/<int:request_id>/reject', methods=['POST'])
@token_required
def reject_friend_request(current_user, session, request_id):
    try:
        friend_request = session.query(FriendRequest).get(request_id)
        
        if not friend_request:
            return jsonify({'message': 'Anfrage nicht gefunden'}), 404
            
        if friend_request.to_user != current_user.id:
            return jsonify({'message': 'Nicht autorisiert'}), 403
            
        if friend_request.status != 'pending':
            return jsonify({'message': 'Anfrage wurde bereits bearbeitet'}), 400
            
        # Lehne die Anfrage ab
        friend_request.status = 'rejected'
        
        return jsonify({'message': 'Freundschaftsanfrage abgelehnt'})
    except SQLAlchemyError as e:
        session.rollback()
        return jsonify({'message': str(e)}), 500

# Position
@app.route('/position', methods=['PUT'])
@token_required
def update_position(current_user, session):
    data = request.get_json()
    
    if not all(k in data for k in ('lat', 'lng')):
        return jsonify({'message': 'Fehlende Koordinaten!'}), 400
        
    position = session.get(Position, current_user.id)
    
    if position:
        position.lat = data['lat']
        position.lng = data['lng']
    else:
        position = Position(
            user=current_user.id,
            lat=data['lat'],
            lng=data['lng']
        )
        session.add(position)
    
    return jsonify({'message': 'Position aktualisiert!'})

@app.route('/positions/friends', methods=['GET'])
@token_required
def get_friends_positions(current_user, session):
    friends_positions = session.query(Friend, Position, User).join(
        Position, Position.user == Friend.friend
    ).join(
        User, User.id == Friend.friend
    ).filter(Friend.user == current_user.id).all()
    
    return jsonify([{
        'user_id': friend.User.id,
        'username': friend.User.username,
        'imgURL': friend.User.imgURL,
        'position': {
            'lat': friend.Position.lat,
            'lng': friend.Position.lng
        }
    } for friend in friends_positions])

if __name__ == '__main__':
    if not os.path.exists('uploads'):
        os.makedirs('uploads')
    app.run(debug=True)