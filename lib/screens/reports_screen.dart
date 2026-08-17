import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_nest_app/models/usage_log.dart';
import 'package:smart_nest_app/services/cloud_sync_service.dart';
import 'package:smart_nest_app/services/usage_service.dart';

/// Usage reporting, built from the `usage_logs` collection the backend
/// worker writes on every status transition. Nothing here is synthesised on
/// the client: the chart, the per-device totals and the safety-cutoff count
/// are all folds over the same event log (see [UsageService.summarise] and
/// [UsageService.dailyTotals]).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _days = 7;

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSyncService();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Usage reports', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: !cloud.isFirebaseAvailable
          ? const _DemoReportsNotice()
          : StreamBuilder<List<UsageLog>>(
              stream: UsageService().streamSince(DateTime.now().subtract(const Duration(days: _days))),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorNotice(message: snapshot.error.toString());
                }
                final logs = snapshot.data ?? const [];
                final daily = UsageService.dailyTotals(logs, _days);
                final summaries = UsageService.summarise(logs);
                final totalOnTime = daily.fold(Duration.zero, (a, b) => a + b);
                final totalCutoffs = summaries.fold(0, (a, s) => a + s.safetyCutoffCount);
                final totalSessions = summaries.fold(0, (a, s) => a + s.sessionCount);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                  children: [
                    Text(
                      'Last $_days days',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'Total ON time',
                            value: DeviceUsageSummary.formatDuration(totalOnTime),
                            icon: Icons.bolt_rounded,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            label: 'Safety cutoffs',
                            value: '$totalCutoffs',
                            icon: Icons.shield_outlined,
                            color: totalCutoffs > 0 ? const Color(0xFFB45309) : Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Daily ON time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            'Minutes devices spent switched on, per day',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 180,
                            child: daily.every((d) => d == Duration.zero)
                                ? Center(
                                    child: Text(
                                      'No activity recorded yet this week.',
                                      style: TextStyle(color: Colors.grey.shade500),
                                    ),
                                  )
                                : _DailyBarChart(daily: daily),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('Devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text(
                          '$totalSessions sessions',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (summaries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                        child: Text(
                          'No usage yet -- switch a device on and off to start collecting data.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else
                      ...summaries.map((s) => _DeviceUsageTile(summary: s)),
                  ],
                );
              },
            ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  final List<Duration> daily;

  const _DailyBarChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    final maxMinutes = daily.map((d) => d.inMinutes).fold(1, (a, b) => a > b ? a : b).toDouble();
    final labels = _weekdayLabels(daily.length);

    return BarChart(
      BarChartData(
        maxY: maxMinutes * 1.2,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[i], style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(daily.length, (i) {
          final minutes = daily[i].inMinutes.toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: minutes,
                width: 18,
                borderRadius: BorderRadius.circular(6),
                color: i == daily.length - 1 ? const Color(0xFF4F46E5) : const Color(0xFFA5B4FC),
              ),
            ],
          );
        }),
      ),
    );
  }

  List<String> _weekdayLabels(int days) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      return names[day.weekday - 1];
    });
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 18, backgroundColor: color.withAlpha((0.12 * 255).round()), child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _DeviceUsageTile extends StatelessWidget {
  final DeviceUsageSummary summary;

  const _DeviceUsageTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.deviceName, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${summary.sessionCount} sessions · avg ${DeviceUsageSummary.formatDuration(summary.averageSession)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (summary.safetyCutoffCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309).withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${summary.safetyCutoffCount} cutoff${summary.safetyCutoffCount > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w700),
              ),
            ),
          Text(summary.formattedTotal, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DemoReportsNotice extends StatelessWidget {
  const _DemoReportsNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Live reports need Firebase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Usage is logged by the backend worker. Run `flutterfire configure` and start the worker to see real charts here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  final String message;

  const _ErrorNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
      ),
    );
  }
}
