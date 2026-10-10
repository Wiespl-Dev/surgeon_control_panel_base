import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wiespl_surgeon_panel/services/nnn.dart'; // OTPanelProvider

class LightIntensityPage extends StatefulWidget {
  @override
  _LightIntensityPageState createState() => _LightIntensityPageState();
}

class _LightIntensityPageState extends State<LightIntensityPage> {
  // Button cooldown management
  bool _isButtonCooldown = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    final otPanelProvider = Provider.of<OTPanelProvider>(
      context,
      listen: false,
    );
    // OTPanelProvider has no separate startPolling(): initialize() does an
    // immediate fetch and (re)starts its internal poll timer, which is the
    // same effect the old esp32Provider.startPolling() call had here.
    otPanelProvider.initialize();
  }

  // Button cooldown management
  void _startCooldown() {
    setState(() {
      _isButtonCooldown = true;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isButtonCooldown = false;
        });
      }
    });
  }

  bool get _canPressButton => !_isButtonCooldown;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    final otPanelProvider = Provider.of<OTPanelProvider>(
      context,
      listen: false,
    );
    otPanelProvider.stopPolling();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _customToggle({
    required String label,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    return Flexible(
      child: Column(
        children: [
          Icon(icon, color: Colors.transparent, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _canPressButton ? onChanged(!value) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              width: 56,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? const Color(0xFF2ECC71) : Colors.white24,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightControlItem({
    required String title,
    required bool isOn,
    required IconData icon,
    required ValueChanged<bool> onToggle,
  }) {
    return Column(
      children: [
        // Title and Custom Toggle
        Padding(
          padding: const EdgeInsets.only(
            left: 20.0,
            right: 16.0,
            top: 10.0,
            bottom: 4.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _customToggle(
                label: isOn ? "" : "",
                value: isOn,
                icon: icon,
                onChanged: onToggle,
              ),
            ],
          ),
        ),

        // Custom Divider Line
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(color: Colors.white38, height: 1, thickness: 0.5),
        ),
      ],
    );
  }

  // Toggle all lights — this page only shows lights 1-4, so it must NOT
  // use OTPanelProvider.setAllLights (that flips all 8 on the panel,
  // including the 4 this screen doesn't show). setLights sends 1-4 in a
  // single write so they switch together.
  void _toggleAllLights(bool newState) async {
    if (!_canPressButton) {
      _showErrorSnackbar("Please wait before pressing another button");
      return;
    }

    _startCooldown();

    final otPanelProvider = Provider.of<OTPanelProvider>(
      context,
      listen: false,
    );

    final ok = await otPanelProvider.setLights({
      for (var id = 1; id <= 4; id++) id: newState,
    });

    if (ok) {
      _showSuccessSnackbar(
        newState ? "All lights turned ON" : "All lights turned OFF",
      );
    } else {
      _showErrorSnackbar(
        "Failed to ${newState ? 'turn on' : 'turn off'} some lights",
      );
    }
  }

  // Toggle individual light — now goes through OTPanelProvider.setLight,
  // which is optimistic (updates lightStates immediately, rolls back on
  // failure) and returns whether the write actually succeeded.
  void _toggleLight(int index, bool newState) async {
    if (!_canPressButton) {
      _showErrorSnackbar("Please wait before pressing another button");
      return;
    }

    _startCooldown();

    final otPanelProvider = Provider.of<OTPanelProvider>(
      context,
      listen: false,
    );

    // Relay/light numbers are 1-based in OTPanelProvider.
    final ok = await otPanelProvider.setLight(index + 1, newState);

    if (ok) {
      _showSuccessSnackbar("Light ${index + 1} ${newState ? 'ON' : 'OFF'}");
    } else {
      _showErrorSnackbar("Failed to set Light ${index + 1}");
    }
  }

  // Get current state for All Lights toggle — checks the first 4 relays
  // (this page only exposes 4 of OTPanelProvider's 8 lights).
  bool _getAllLightsState() {
    final otPanelProvider = Provider.of<OTPanelProvider>(context);
    return otPanelProvider.lightStates[0] ||
        otPanelProvider.lightStates[1] ||
        otPanelProvider.lightStates[2] ||
        otPanelProvider.lightStates[3];
  }

  // Get individual light state
  bool _getLightState(int index) {
    final otPanelProvider = Provider.of<OTPanelProvider>(context);
    if (index < 0 || index >= otPanelProvider.lightStates.length) return false;
    return otPanelProvider.lightStates[index];
  }

  // Manual refresh — OTPanelProvider doesn't expose a standalone
  // refresh/fetch method, so this re-runs initialize(), which does an
  // immediate fetch and restarts its poll timer.
  void _manualRefresh() {
    if (!_canPressButton) {
      _showErrorSnackbar("Please wait before pressing another button");
      return;
    }

    _startCooldown();

    final otPanelProvider = Provider.of<OTPanelProvider>(
      context,
      listen: false,
    );
    otPanelProvider.initialize();
    _showSuccessSnackbar("Refreshing data...");
  }

  @override
  Widget build(BuildContext context) {
    final otPanelProvider = Provider.of<OTPanelProvider>(context);

    return Material(
      color: const Color.fromARGB(255, 35, 87, 136),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double modalWidth = constraints.maxWidth * 0.9;
            final double modalHeight = constraints.maxHeight * 0.9;

            return Container(
              width: modalWidth.clamp(300.0, 600.0),
              height: modalHeight.clamp(400.0, 800.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    const Color.fromARGB(255, 35, 87, 136),
                    Color.fromARGB(193, 95, 139, 184),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // HEADER: Title and Close Button
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 16.0,
                      left: 20.0,
                      right: 16.0,
                      bottom: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Light Control",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Connection status and close button
                        Row(
                          children: [
                            // Connection Status
                            Container(
                              padding: const EdgeInsets.symmetric(
                                // horizontal: 1,
                                // vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: otPanelProvider.isConnected
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Text(
                                  //   otPanelProvider.isConnected
                                  //       ? "CONNECTED"
                                  //       : "OFFLINE",
                                  //   style: const TextStyle(
                                  //     color: Colors.white,
                                  //     fontSize: 10,
                                  //     fontWeight: FontWeight.bold,
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Refresh button
                            IconButton(
                              onPressed: _manualRefresh,
                              icon: Icon(
                                Icons.refresh,
                                color: _canPressButton
                                    ? Colors.white
                                    : Colors.grey,
                                size: 20,
                              ),
                            ),
                            // Close button
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // The solid line divider under the title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(
                      color: Colors.white,
                      height: 1,
                      thickness: 0.5,
                    ),
                  ),

                  // Cooldown indicator
                  if (_isButtonCooldown)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.orange.withOpacity(0.3),
                      child: const Center(
                        child: Text(
                          "Please wait...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // SCROLLABLE LIGHT CONTROLS
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: <Widget>[
                        // 1. ALL LIGHTS Master Control
                        _buildLightControlItem(
                          title: "All Lights",
                          isOn: _getAllLightsState(),
                          icon: Icons.lightbulb_outline,
                          onToggle: (v) {
                            _toggleAllLights(v);
                          },
                        ),

                        // 2. Individual Light Controls (4 Lights)
                        ...List.generate(4, (index) {
                          return _buildLightControlItem(
                            title: "Light ${index + 1}",
                            isOn: _getLightState(index),
                            icon: Icons.lightbulb,
                            onToggle: (v) {
                              _toggleLight(index, v);
                            },
                          );
                        }),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0, left: 10),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            "BACK",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}