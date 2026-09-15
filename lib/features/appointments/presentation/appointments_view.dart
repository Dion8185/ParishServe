import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';
import 'dialogs/schedule_appointment_dialog.dart';
import 'widgets/appointment_card.dart';

class AppointmentsView extends StatefulWidget {
  const AppointmentsView({super.key});

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  final TextEditingController _searchController = TextEditingController();
  List<AppointmentModel> _appointments = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _filterTabs = ['All', 'Confirmed', 'Pending', 'Rescheduled', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AppointmentService.getAppointments(
        statusFilter: _selectedFilter == 'All' ? null : _selectedFilter,
      );
      if (!mounted) return;
      setState(() => _appointments = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AppointmentModel> get _filteredList {
    if (_searchQuery.trim().isEmpty) return _appointments;
    final q = _searchQuery.toLowerCase();
    return _appointments.where((a) {
      final name = a.requesterName.toLowerCase().contains(q);
      final service = a.serviceType.toLowerCase().contains(q);
      final id = a.appointmentId.toLowerCase().contains(q);
      final venue = a.venue.toLowerCase().contains(q);
      return name || service || id || venue;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parish Appointments', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDarkColor)),
            Text('Schedule weddings, baptisms, mass intentions & pastoral duties', style: TextStyle(color: textMutedColor)),
            const SizedBox(height: 18),

            // Primary Booking Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.goldAccent,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => showScheduleAppointmentModal(context, onAppointmentSaved: _loadAppointments),
                icon: const Icon(Icons.add_task, size: 24),
                label: const Text('+ Book New Appointment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 18),

            // Search Bar
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardWhiteColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderGreyColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 22, color: ParishColors.marianBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(fontSize: 14, color: textDarkColor),
                      decoration: InputDecoration(
                        hintText: 'Search by requester, service, or booking ID...',
                        hintStyle: TextStyle(fontSize: 13, color: textMutedColor),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterTabs.map((tab) {
                  final isSelected = _selectedFilter == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedFilter = tab);
                        _loadAppointments();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? ParishColors.marianBlue : cardWhiteColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? ParishColors.marianBlue : borderGreyColor),
                        ),
                        child: Text(
                          tab,
                          style: TextStyle(
                            color: isSelected ? Colors.white : textMutedColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scheduled Parish Services', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDarkColor)),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: ParishColors.marianBlue),
                  onPressed: _loadAppointments,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Body List Area
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ParishColors.mercyRedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ParishColors.mercyRed),
                ),
                child: Text('Error loading appointments: $_errorMessage', style: const TextStyle(color: ParishColors.mercyRed)),
              )
            else if (_filteredList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cardWhiteColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderGreyColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 42, color: textMutedColor),
                      const SizedBox(height: 10),
                      Text('No appointments found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDarkColor)),
                      const SizedBox(height: 4),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try clearing your search query.'
                            : 'Tap "+ Book New Appointment" to schedule a service.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: textMutedColor),
                      ),
                    ],
                  ),
                )
              else
                ..._filteredList.map((apt) => AppointmentCard(
                  appointment: apt,
                  onRefresh: _loadAppointments,
                )),
          ],
        ),
      ),
    );
  }
}