import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:stay_near/app_constants.dart';
import 'package:stay_near/components/my_drawer.dart';
import 'package:stay_near/components/pin_pointer.dart';
import 'package:stay_near/pages/friends_page.dart';
import 'package:stay_near/services/api_service.dart';
import 'package:stay_near/components/friends_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  List<Marker> markers = [];
  LatLng myLocation = LatLng(0, 0);
  String currentMapStyle = AppConstants.mapBoxStyleDarkId;
  Timer? _locationTimer;
  Timer? _friendsTimer;
  List<FriendLocation> friendLocations = [];

  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _startLocationUpdates();
    
    // Initial laden und Timer starten
    _loadFriendsLocations();
    _startFriendsUpdates();

    // Einfacher Callback der nur den State aktualisiert
    _apiService.setOnFriendsUpdateCallback((newLocations) {
      if (mounted) {
        setState(() {
          friendLocations = newLocations;
          markers = _apiService.friendLocationsToMarkers(newLocations);
        });
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _friendsTimer?.cancel();
    _apiService.removeOnFriendsUpdateCallback();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      final position = await _getCurrentPosition();
      setState(() {
        myLocation = LatLng(position.latitude, position.longitude);
      });
      // Position beim Start aktualisieren
      await _updateMyLocation(position);
    } catch (e) {
      _showError('Fehler beim Laden der Position: $e');
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final position = await _getCurrentPosition();
        setState(() {
          myLocation = LatLng(position.latitude, position.longitude);
        });
        await _updateMyLocation(position);
      } catch (e) {
        _showError('Fehler beim Aktualisieren der Position: $e');
      }
    });
  }

  void _startFriendsUpdates() {
    _friendsTimer?.cancel();
    _friendsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadFriendsLocations();
    });
  }

  Future<void> _updateMyLocation(Position position) async {
    final response = await _apiService.updatePosition(
      position.latitude,
      position.longitude,
    );

    if (!response.success) {
      _showError(response.message ?? 'Fehler beim Aktualisieren der Position');
    }
  }

  Future<void> _loadFriendsLocations() async {
  if (!mounted) return;

  final response = await _apiService.getFriendsLocations();
  if (response.success && response.data != null && mounted) {
    setState(() {
      friendLocations = response.data!;
      markers = friendLocations.map((friend) => Marker(
        point: LatLng(friend.lat, friend.lng),
        child: PinPointer(imgUrl: friend.imgURL),
      )).toList();
    });
  } else if (mounted) {
    _showError(response.message ?? 'Fehler beim Laden der Freunde');
  }
}

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Standortdienste sind deaktiviert.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Standortberechtigungen wurden verweigert');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Standortberechtigungen wurden dauerhaft verweigert. Bitte in den Einstellungen aktivieren.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _animatedMoveAndZoom(LatLng location) async {
    // First move to location
    _mapController.move(location, 13.0);
    
    // Then zoom in with animation
    for (double zoom = 13.0; zoom <= 18.0; zoom += 0.5) {
      await Future.delayed(const Duration(milliseconds: 50));
      _mapController.move(location, zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      drawer: MyDrawer(),
      body: SlidingUpPanel(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
        minHeight: MediaQuery.of(context).size.height * 0.15,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        color: const Color.fromARGB(255, 34, 34, 34),
        panel: Material(
          color: Colors.transparent,
          child: FriendsPage(
            onFriendsUpdate: (List<FriendLocation> newLocations) {
              setState(() {
                friendLocations = newLocations;
                markers = newLocations.map((friend) => Marker(
                  point: LatLng(friend.lat, friend.lng),
                  child: PinPointer(imgUrl: friend.imgURL),
                )).toList();
              });
            },
          ),
        ),
        collapsed: Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 34, 34, 34),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: FriendsList(
            friends: friendLocations,
            onNavigateToLocation: (LatLng location) => _animatedMoveAndZoom(location),
          ),
        ),
        body: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            backgroundColor: const Color.fromARGB(0, 255, 255, 255),
            initialCenter: myLocation,
            initialZoom: 13.0,
            minZoom: 5.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: AppConstants.urlTemplate,
              fallbackUrl: AppConstants.urlTemplate,
              additionalOptions: {
                'id': currentMapStyle,
              },
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}
