import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPicker extends StatefulWidget {
  final LatLng? initialLocation;

  LocationPicker({this.initialLocation});

  @override
  _LocationPickerState createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late LatLng? pickedLocation = null;
  bool hasInitialLocation = false;
  GoogleMapController? mapController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLocation == null) {
        pickedLocation = LatLng(24.7136, 46.6753); // Default location "Riyadh"
      } else {
        pickedLocation = widget.initialLocation;
        hasInitialLocation = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pick Location'),
      ),
      body: GoogleMap(
        onMapCreated: (controller) {
          setState(() {
            mapController = controller;
          });
        },
        initialCameraPosition: CameraPosition(
          target: pickedLocation ?? LatLng(24.7136, 46.6753),
          zoom: 11.0,
        ),
        onTap: (LatLng location) {
          setState(() {
            if (!hasInitialLocation) {
              pickedLocation = location;
            }
          });
        },
        markers: {
          if (pickedLocation != null)
            Marker(
              markerId: MarkerId('pickedLocation'),
              position: pickedLocation!,
            ),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context, pickedLocation),
        child: Icon(Icons.check),
      ),
    );
  }
}
