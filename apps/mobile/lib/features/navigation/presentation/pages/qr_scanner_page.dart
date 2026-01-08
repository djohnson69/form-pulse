import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  bool _isScanning = false;
  _ScannedAsset? _scannedItem;
  List<_RecentScan> _recentScans = List.from(_demoRecentScans);

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code Scanner')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(context, isDark),
                  const SizedBox(height: 16),
                  _buildScanGrid(context, isDark),
                  const SizedBox(height: 16),
                  _buildRecentScans(context, isDark),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QR Code Scanner',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Scan asset QR codes for instant information and tracking',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildScanGrid(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final scannerCard = _buildScannerCard(context, isDark);
        final resultsCard = _buildResultsCard(context, isDark);
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: scannerCard),
              const SizedBox(width: 16),
              Expanded(child: resultsCard),
            ],
          );
        }
        return Column(
          children: [
            scannerCard,
            const SizedBox(height: 16),
            resultsCard,
          ],
        );
      },
    );
  }

  Widget _buildScannerCard(BuildContext context, bool isDark) {
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan QR Code',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B1220) : Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isScanning
                  ? _ScanningOverlay(controller: _scanController)
                  : _IdleScannerOverlay(isDark: isDark),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _isScanning
                  ? (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))
                  : const Color(0xFF2563EB),
              foregroundColor: _isScanning
                  ? (isDark ? Colors.grey[400] : Colors.grey[600])
                  : Colors.white,
            ),
            onPressed: _isScanning ? null : _startScan,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(_isScanning ? 'Scanning...' : 'Start Scan'),
          ),
          const SizedBox(height: 12),
          _TipsBanner(isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildResultsCard(BuildContext context, bool isDark) {
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan Results',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          if (_scannedItem == null)
            const _EmptyResults()
          else
            _ResultsDetails(
              asset: _scannedItem!,
              onClear: () => setState(() => _scannedItem = null),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentScans(BuildContext context, bool isDark) {
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Scans',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          ..._recentScans.map((scan) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecentScanTile(scan: scan),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    _scanController.repeat();
    try {
      final result = await BarcodeScanner.scan();
      if (!mounted) return;
      if (result.type == ResultType.Cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan cancelled')),
        );
        return;
      }
      final scannedId = result.rawContent.trim();
      final asset = _demoAsset.copyWith(
        id: scannedId.isEmpty ? _demoAsset.id : scannedId,
      );
      setState(() => _scannedItem = asset);
      _recordScan(asset);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    } finally {
      if (mounted) {
        _scanController.stop();
        setState(() => _isScanning = false);
      }
    }
  }

  void _recordScan(_ScannedAsset asset) {
    final scan = _RecentScan(
      id: asset.id,
      name: asset.name,
      timeLabel: 'just now',
      location: asset.location,
    );
    setState(() {
      _recentScans = [
        scan,
        ..._recentScans.where((item) => item.id != scan.id),
      ].take(5).toList();
    });
  }
}

class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameSize = constraints.maxWidth * 0.7;
        return Center(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return SizedBox(
                width: frameSize,
                height: frameSize,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF2563EB),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Positioned(
                      top: controller.value * (frameSize - 2),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _IdleScannerOverlay extends StatelessWidget {
  const _IdleScannerOverlay({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_2,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[600],
          ),
          const SizedBox(height: 12),
          Text(
            'Position QR code in frame',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
          ),
        ],
      ),
    );
  }
}

class _TipsBanner extends StatelessWidget {
  const _TipsBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A8A).withOpacity(0.2)
            : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1D4ED8).withOpacity(0.4)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.qr_code_scanner_outlined,
            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Scan Tips:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFBFDBFE)
                            : const Color(0xFF1D4ED8),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '- Ensure good lighting\n- Hold camera steady\n- Position code within frame',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? const Color(0xFFBFDBFE)
                            : const Color(0xFF1D4ED8),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsDetails extends StatelessWidget {
  const _ResultsDetails({required this.asset, required this.onClear});

  final _ScannedAsset asset;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14532D).withOpacity(0.2)
                : const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF15803D).withOpacity(0.4)
                  : const Color(0xFFBBF7D0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asset Found',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFF166534),
                          ),
                    ),
                    Text(
                      'Successfully scanned asset QR code',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? const Color(0xFFBBF7D0)
                                : const Color(0xFF15803D),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailRow(label: 'Asset ID', value: asset.id, isMonospace: true),
        _DetailRow(label: 'Name', value: asset.name),
        Row(
          children: [
            Expanded(
              child: _DetailRow(label: 'Category', value: asset.category),
            ),
            Expanded(
              child: _StatusBadge(label: asset.status),
            ),
          ],
        ),
        _DetailRow(
          label: 'Current Location',
          value: asset.location,
          icon: Icons.place_outlined,
        ),
        _DetailRow(label: 'Assigned To', value: asset.assignedTo),
        Row(
          children: [
            Expanded(
              child: _DetailRow(
                label: 'Last Inspection',
                value: asset.lastInspection,
              ),
            ),
            Expanded(
              child: _DetailRow(
                label: 'Next Inspection',
                value: asset.nextInspection,
                highlight: true,
              ),
            ),
          ],
        ),
        _BadgeRow(label: 'Condition', value: asset.condition),
        _DetailRow(label: 'Notes', value: asset.notes),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {},
                child: const Text('View Full Details'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Update Status'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onClear,
          child: const Text('Scan Another Code'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.isMonospace = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool isMonospace;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
              ],
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: highlight
                  ? (isDark ? const Color(0xFFF97316) : const Color(0xFFEA580C))
                  : (isDark ? Colors.grey[100] : Colors.grey[900]),
              fontFamily: isMonospace ? 'monospace' : null,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATUS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF14532D).withOpacity(0.2)
                  : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFF15803D),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E3A8A).withOpacity(0.2)
                  : const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 56,
          color: isDark ? Colors.grey[700] : Colors.grey[300],
        ),
        const SizedBox(height: 12),
        Text(
          'No scan results yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Scan a QR code to view asset details',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
        ),
      ],
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  const _RecentScanTile({required this.scan});

  final _RecentScan scan;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.qr_code_2,
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${scan.id} - ${scan.location}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          Text(
            scan.timeLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }
}

class _ScannedAsset {
  const _ScannedAsset({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.location,
    required this.assignedTo,
    required this.lastInspection,
    required this.nextInspection,
    required this.condition,
    required this.notes,
  });

  final String id;
  final String name;
  final String category;
  final String status;
  final String location;
  final String assignedTo;
  final String lastInspection;
  final String nextInspection;
  final String condition;
  final String notes;

  _ScannedAsset copyWith({
    String? id,
  }) {
    return _ScannedAsset(
      id: id ?? this.id,
      name: name,
      category: category,
      status: status,
      location: location,
      assignedTo: assignedTo,
      lastInspection: lastInspection,
      nextInspection: nextInspection,
      condition: condition,
      notes: notes,
    );
  }
}

class _RecentScan {
  const _RecentScan({
    required this.id,
    required this.name,
    required this.timeLabel,
    required this.location,
  });

  final String id;
  final String name;
  final String timeLabel;
  final String location;
}

const _ScannedAsset _demoAsset = _ScannedAsset(
  id: 'AST-2024-1234',
  name: 'Hydraulic Excavator CAT 320',
  category: 'Heavy Equipment',
  status: 'In Use',
  location: 'Building A - Main Site',
  assignedTo: 'John Smith',
  lastInspection: 'Dec 20, 2025',
  nextInspection: 'Jan 3, 2026',
  condition: 'Good',
  notes: 'Regular maintenance completed. All systems operational.',
);

const List<_RecentScan> _demoRecentScans = [
  _RecentScan(
    id: 'AST-2024-1234',
    name: 'Hydraulic Excavator CAT 320',
    timeLabel: '2 hours ago',
    location: 'Building A',
  ),
  _RecentScan(
    id: 'AST-2024-0987',
    name: 'Concrete Mixer',
    timeLabel: '5 hours ago',
    location: 'Site B',
  ),
  _RecentScan(
    id: 'AST-2024-0654',
    name: 'Safety Harness Set',
    timeLabel: '1 day ago',
    location: 'Warehouse',
  ),
];
