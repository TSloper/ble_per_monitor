import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/radio_parameters.dart';
import '../services/ble_service.dart';

/// Screen for viewing and modifying RF parameters
class ParametersScreen extends StatefulWidget {
  const ParametersScreen({super.key});

  @override
  State<ParametersScreen> createState() => _ParametersScreenState();
}

class _ParametersScreenState extends State<ParametersScreen> {
  final BleService _bleService = BleService();
  final _customFrequencyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Current parameters from device
  RadioParameters? _currentParameters;

  // Modified parameters (user is editing)
  int _frequencyHz = RadioParameters.freq915MHz;
  int _spreadingFactor = 7;
  int _bandwidth = 0;
  int _txPower = 14;

  // UI state
  bool _isLoading = false;
  bool _isWriting = false;
  String _selectedFrequencyPreset = '915 MHz (US)';
  bool _useCustomFrequency = false;

  // Frequency presets
  final Map<String, int> _frequencyPresets = {
    '868 MHz (EU)': RadioParameters.freq868MHz,
    '915 MHz (US)': RadioParameters.freq915MHz,
    '923 MHz (Asia)': 923000000,
    'Custom': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentParameters();
    _subscribeToParameterUpdates();
  }

  @override
  void dispose() {
    _customFrequencyController.dispose();
    super.dispose();
  }

  /// Load current parameters from device
  Future<void> _loadCurrentParameters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Parameters are already being read by BleService
      // Just get the current values
      final params = _bleService.currentParameters;
      setState(() {
        _currentParameters = params;
        _frequencyHz = params.frequency;
        _spreadingFactor = params.spreadingFactor;
        _bandwidth = params.bandwidth;
        _txPower = params.txPower;

        // Set preset or custom
        _updateFrequencyPreset(params.frequency);
      });
    } catch (e) {
      _showError('Failed to load parameters: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Subscribe to parameter updates from device
  void _subscribeToParameterUpdates() {
    _bleService.parametersStream.listen((params) {
      if (mounted) {
        setState(() {
          _currentParameters = params;
        });
      }
    });
  }

  /// Update frequency preset selection based on frequency
  void _updateFrequencyPreset(int frequencyHz) {
    bool foundPreset = false;
    for (final entry in _frequencyPresets.entries) {
      if (entry.value == frequencyHz && entry.key != 'Custom') {
        _selectedFrequencyPreset = entry.key;
        _useCustomFrequency = false;
        foundPreset = true;
        break;
      }
    }

    if (!foundPreset) {
      _selectedFrequencyPreset = 'Custom';
      _useCustomFrequency = true;
      _customFrequencyController.text = (frequencyHz / 1000000).toString();
    }
  }

  /// Check if parameters have been modified
  bool get _hasChanges {
    if (_currentParameters == null) return false;
    return _frequencyHz != _currentParameters!.frequency ||
        _spreadingFactor != _currentParameters!.spreadingFactor ||
        _bandwidth != _currentParameters!.bandwidth ||
        _txPower != _currentParameters!.txPower;
  }

  /// Validate all parameters
  bool _validateParameters() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    final params = RadioParameters(
      frequency: _frequencyHz,
      spreadingFactor: _spreadingFactor,
      bandwidth: _bandwidth,
      txPower: _txPower,
    );

    if (!params.isValid) {
      final errors = params.getValidationErrors();
      _showError(errors.join('\n'));
      return false;
    }

    return true;
  }

  /// Apply parameter changes to device
  Future<void> _applyChanges() async {
    if (!_validateParameters()) {
      return;
    }

    // Confirm potentially disruptive changes
    if (_frequencyHz != _currentParameters?.frequency ||
        _spreadingFactor != _currentParameters?.spreadingFactor ||
        _bandwidth != _currentParameters?.bandwidth) {
      final confirmed = await _showConfirmationDialog(
        'Apply Changes?',
        'Changing RF parameters may temporarily disrupt communication. Continue?',
      );
      if (!confirmed) return;
    }

    setState(() {
      _isWriting = true;
    });

    try {
      final params = RadioParameters(
        frequency: _frequencyHz,
        spreadingFactor: _spreadingFactor,
        bandwidth: _bandwidth,
        txPower: _txPower,
      );

      await _bleService.writeRadioParameters(params);

      if (mounted) {
        _showSuccess('Parameters applied successfully');
      }
    } catch (e) {
      _showError('Failed to apply parameters: $e');
    } finally {
      setState(() {
        _isWriting = false;
      });
    }
  }

  /// Revert changes to current parameters
  void _revertChanges() {
    if (_currentParameters != null) {
      setState(() {
        _frequencyHz = _currentParameters!.frequency;
        _spreadingFactor = _currentParameters!.spreadingFactor;
        _bandwidth = _currentParameters!.bandwidth;
        _txPower = _currentParameters!.txPower;
        _updateFrequencyPreset(_frequencyHz);
      });
    }
  }

  /// Show confirmation dialog
  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show success message
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RF Parameters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadCurrentParameters,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Current Configuration Card
                    _buildCurrentConfigCard(colorScheme),
                    const SizedBox(height: 16),

                    // Frequency Control
                    _buildFrequencyControl(colorScheme),
                    const SizedBox(height: 16),

                    // Spreading Factor Control
                    _buildSpreadingFactorControl(colorScheme),
                    const SizedBox(height: 16),

                    // Bandwidth Control
                    _buildBandwidthControl(colorScheme),
                    const SizedBox(height: 16),

                    // TX Power Control
                    _buildTxPowerControl(colorScheme),
                    const SizedBox(height: 24),

                    // Action Buttons
                    _buildActionButtons(colorScheme),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  /// Build current configuration card
  Widget _buildCurrentConfigCard(ColorScheme colorScheme) {
    if (_currentParameters == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_input_antenna, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Current Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildConfigRow(
              'Frequency',
              _currentParameters!.frequencyFormatted,
              Icons.radio,
            ),
            const Divider(),
            _buildConfigRow(
              'Spreading Factor',
              _currentParameters!.spreadingFactorFormatted,
              Icons.timeline,
            ),
            const Divider(),
            _buildConfigRow(
              'Bandwidth',
              _currentParameters!.bandwidthFormatted,
              Icons.tune,
            ),
            const Divider(),
            _buildConfigRow(
              'TX Power',
              _currentParameters!.txPowerFormatted,
              Icons.power,
            ),
          ],
        ),
      ),
    );
  }

  /// Build configuration row
  Widget _buildConfigRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  /// Build frequency control
  Widget _buildFrequencyControl(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.radio, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Frequency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preset dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedFrequencyPreset,
              decoration: const InputDecoration(
                labelText: 'Frequency Preset',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.public),
              ),
              items: _frequencyPresets.keys.map((preset) {
                return DropdownMenuItem(
                  value: preset,
                  child: Text(preset),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedFrequencyPreset = value;
                    if (value == 'Custom') {
                      _useCustomFrequency = true;
                    } else {
                      _useCustomFrequency = false;
                      _frequencyHz = _frequencyPresets[value]!;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Custom frequency input
            if (_useCustomFrequency)
              TextFormField(
                controller: _customFrequencyController,
                decoration: const InputDecoration(
                  labelText: 'Custom Frequency (MHz)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                  suffixText: 'MHz',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a frequency';
                  }
                  final freq = double.tryParse(value);
                  if (freq == null) {
                    return 'Invalid frequency';
                  }
                  if (freq < 300 || freq > 1000) {
                    return 'Frequency must be between 300-1000 MHz';
                  }
                  return null;
                },
                onChanged: (value) {
                  final freq = double.tryParse(value);
                  if (freq != null) {
                    setState(() {
                      _frequencyHz = (freq * 1000000).round();
                    });
                  }
                },
              ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ensure compliance with local frequency regulations. '
                      'Using unauthorized frequencies may be illegal.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build spreading factor control
  Widget _buildSpreadingFactorControl(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Spreading Factor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'SF$_spreadingFactor',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),

            // Slider
            Slider(
              value: _spreadingFactor.toDouble(),
              min: 5,
              max: 12,
              divisions: 7,
              label: 'SF$_spreadingFactor',
              onChanged: (value) {
                setState(() {
                  _spreadingFactor = value.round();
                });
              },
            ),

            // SF markers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SF5', style: Theme.of(context).textTheme.bodySmall),
                  Text('SF12', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Visual explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildSfTradeoff(
                    'Lower SF (5-7)',
                    'Faster transmission, shorter range, less robust',
                    Icons.flash_on,
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _buildSfTradeoff(
                    'Higher SF (10-12)',
                    'Slower transmission, longer range, more robust',
                    Icons.radar,
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build SF tradeoff row
  Widget _buildSfTradeoff(
      String title, String description, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build bandwidth control
  Widget _buildBandwidthControl(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Bandwidth',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Radio buttons
            _buildBandwidthOption(
              0,
              '125 kHz',
              'Longest range, slowest data rate',
              colorScheme,
            ),
            const SizedBox(height: 8),
            _buildBandwidthOption(
              1,
              '250 kHz',
              'Balanced range and data rate',
              colorScheme,
            ),
            const SizedBox(height: 8),
            _buildBandwidthOption(
              2,
              '500 kHz',
              'Shortest range, fastest data rate',
              colorScheme,
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.tertiary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Higher bandwidth = faster data rate but reduced sensitivity and range.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build bandwidth option
  Widget _buildBandwidthOption(
      int value, String label, String description, ColorScheme colorScheme) {
    final isSelected = _bandwidth == value;
    return InkWell(
      onTap: () {
        setState(() {
          _bandwidth = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? colorScheme.primary : null,
                        ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build TX power control
  Widget _buildTxPowerControl(ColorScheme colorScheme) {
    final isHighPower = _txPower > 17;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.power, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'TX Power',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '$_txPower dBm',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isHighPower ? Colors.orange : colorScheme.primary,
                      ),
                ),
                const SizedBox(width: 12),
                _buildPowerIndicator(_txPower),
              ],
            ),
            const SizedBox(height: 16),

            // Slider
            Slider(
              value: _txPower.toDouble(),
              min: -9,
              max: 22,
              divisions: 31,
              label: '$_txPower dBm',
              onChanged: (value) {
                setState(() {
                  _txPower = value.round();
                });
              },
            ),

            // Power markers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('-9 dBm', style: Theme.of(context).textTheme.bodySmall),
                  Text('+22 dBm', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // High power warning
            if (isHighPower)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      size: 20,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'High TX power may require regulatory approval and increases power consumption.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange[900],
                            ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildPowerTradeoff(
                    'Lower Power (-9 to 0 dBm)',
                    'Reduced range, lower power consumption',
                    Icons.battery_charging_full,
                    Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _buildPowerTradeoff(
                    'Higher Power (14 to 22 dBm)',
                    'Extended range, higher power consumption',
                    Icons.battery_alert,
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build power indicator
  Widget _buildPowerIndicator(int power) {
    final strength = power < 0 ? 1 : (power < 10 ? 2 : (power < 17 ? 3 : 4));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isActive = index < strength;
        final color = strength >= 4
            ? Colors.orange
            : (strength >= 3 ? Colors.green : Colors.blue);
        return Container(
          width: 6,
          height: 12.0 + (index * 4),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  /// Build power tradeoff row
  Widget _buildPowerTradeoff(
      String title, String description, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _hasChanges ? _revertChanges : null,
            icon: const Icon(Icons.undo),
            label: const Text('Revert'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _hasChanges && !_isWriting ? _applyChanges : null,
            icon: _isWriting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_isWriting ? 'Applying...' : 'Apply Changes'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}
