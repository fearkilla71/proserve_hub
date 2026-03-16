import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/crew_invite_service.dart';
import '../utils/app_error_handler.dart';

class CrewMemberPortalScreen extends StatefulWidget {
  const CrewMemberPortalScreen({super.key, this.initialInviteCode});

  final String? initialInviteCode;

  @override
  State<CrewMemberPortalScreen> createState() => _CrewMemberPortalScreenState();
}

class _CrewMemberPortalScreenState extends State<CrewMemberPortalScreen> {
  final _codeCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;

  String? _contractorId;
  String? _crewMemberId;
  String _crewName = 'Crew Member';
  String _roleTitle = 'Crew Member';

  bool _onShift = false;
  bool _shareLocation = false;

  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    final code = widget.initialInviteCode?.trim();
    if (code != null && code.isNotEmpty) {
      _codeCtrl.text = code.toUpperCase();
    }
    _refreshLink();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshLink() async {
    setState(() => _loading = true);
    try {
      final link = await CrewInviteService.instance.getCrewLink();
      if (!mounted) return;
      if (link == null) {
        setState(() {
          _contractorId = null;
          _crewMemberId = null;
          _crewName = 'Crew Member';
          _roleTitle = 'Crew Member';
          _onShift = false;
          _shareLocation = false;
        });
      } else {
        setState(() {
          _contractorId = (link['contractorId'] as String?) ?? '';
          _crewMemberId = (link['crewMemberId'] as String?) ?? '';
          _crewName = (link['crewName'] as String?) ?? 'Crew Member';
          _roleTitle = (link['role'] as String?) ?? 'Crew Member';
          _onShift = (link['onShift'] as bool?) == true;
          _shareLocation = (link['locationSharingEnabled'] as bool?) == true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load crew link.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() => _busy = true);
    try {
      await CrewInviteService.instance.redeemInviteCode(code);
      if (!mounted) return;
      _codeCtrl.clear();
      await _refreshLink();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined crew successfully.')),
      );
    } catch (e, st) {
      if (!mounted) return;
      AppError.show(context, e, st, action: 'redeem invite');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setShareLocation(bool value) async {
    final contractorId = _contractorId;
    final crewMemberId = _crewMemberId;
    if (contractorId == null ||
        contractorId.isEmpty ||
        crewMemberId == null ||
        crewMemberId.isEmpty) {
      return;
    }

    setState(() => _shareLocation = value);
    await CrewInviteService.instance.updateCrewShift(
      contractorId: contractorId,
      crewMemberId: crewMemberId,
      locationSharingEnabled: value,
    );

    if (!value) {
      await _stopLocationStream();
    } else if (_onShift) {
      await _startLocationStream();
    }
  }

  Future<void> _setOnShift(bool value) async {
    final contractorId = _contractorId;
    final crewMemberId = _crewMemberId;
    if (contractorId == null ||
        contractorId.isEmpty ||
        crewMemberId == null ||
        crewMemberId.isEmpty) {
      return;
    }

    setState(() => _onShift = value);
    await CrewInviteService.instance.updateCrewShift(
      contractorId: contractorId,
      crewMemberId: crewMemberId,
      onShift: value,
    );

    if (_shareLocation && value) {
      await _startLocationStream();
    } else {
      await _stopLocationStream();
    }
  }

  Future<void> _startLocationStream() async {
    final contractorId = _contractorId;
    final crewMemberId = _crewMemberId;
    if (contractorId == null ||
        contractorId.isEmpty ||
        crewMemberId == null ||
        crewMemberId.isEmpty) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable location services to share live position.'),
        ),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for live tracking.'),
        ),
      );
      return;
    }

    await _locationSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );

    _locationSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) async {
          if (!_onShift || !_shareLocation) return;
          await CrewInviteService.instance.pushCrewLocation(
            contractorId: contractorId,
            crewMemberId: crewMemberId,
            position: position,
          );
        });
  }

  Future<void> _stopLocationStream() async {
    await _locationSub?.cancel();
    _locationSub = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final linked = _contractorId != null && _contractorId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Crew Member Portal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!linked) ...[
            Text(
              'Join a contractor crew',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the invite code provided by your contractor.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _redeem,
                child: Text(_busy ? 'Joining...' : 'Join Crew'),
              ),
            ),
          ] else ...[
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                title: Text(_crewName),
                subtitle: Text(_roleTitle),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _shareLocation,
              onChanged: (v) => _setShareLocation(v),
              title: const Text('Share location while on shift'),
              subtitle: const Text('You can turn this off at any time.'),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _onShift
                                ? null
                                : () => _setOnShift(true),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Shift'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: !_onShift
                                ? null
                                : () => _setOnShift(false),
                            icon: const Icon(Icons.stop),
                            label: const Text('End Shift'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _onShift
                          ? 'You are currently on shift.'
                          : 'You are currently off shift.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
