import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AssistanceApp());
}

const teal = Color(0xFF0D9488);
const navy = Color(0xFF123047);

class AssistanceApp extends StatelessWidget {
  const AssistanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PWD & Senior Citizen Assistance Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
        scaffoldBackgroundColor: const Color(0xFFF5F8FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const PortalHome(),
    );
  }
}

class AssistanceRequest {
  final String id;
  final String name;
  final String category;
  final String service;
  final String contact;
  final String details;
  final String status;

  const AssistanceRequest({
    required this.id,
    required this.name,
    required this.category,
    required this.service,
    required this.contact,
    required this.details,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'service': service,
      'contact': contact,
      'details': details,
      'status': status,
    };
  }

  factory AssistanceRequest.fromJson(Map<String, dynamic> json) {
    return AssistanceRequest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'PWD',
      service: json['service']?.toString() ?? '',
      contact: json['contact']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
    );
  }
}

class PortalHome extends StatefulWidget {
  const PortalHome({super.key});

  @override
  State<PortalHome> createState() => _PortalHomeState();
}

class _PortalHomeState extends State<PortalHome> {
  int selectedIndex = 0;

  List<AssistanceRequest> requests = [];
  List<dynamic> holidays = [];

  bool loading = true;
  bool loadingHolidays = false;

  String? holidayError;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    loadRequests();
    loadHolidays();
  }

  Future<void> loadRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('assistance_requests');

      if (saved != null) {
        final decoded = jsonDecode(saved) as List;

        requests = decoded
            .map(
              (item) =>
                  AssistanceRequest.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    } catch (_) {
      requests = [];
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> saveRequests() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'assistance_requests',
      jsonEncode(requests.map((request) => request.toJson()).toList()),
    );
  }

  Future<void> loadHolidays() async {
    if (!mounted) return;

    setState(() {
      loadingHolidays = true;
      holidayError = null;
    });

    try {
      final year = DateTime.now().year;

      final response = await http
          .get(
            Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$year/PH'),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Unable to retrieve holiday data.');
      }

      final data = jsonDecode(response.body) as List;

      if (!mounted) return;

      setState(() {
        holidays = data;
        loadingHolidays = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        holidayError = 'Unable to load holidays. Check your internet.';
        loadingHolidays = false;
      });
    }
  }

  Future<void> openRequestForm({
    AssistanceRequest? existing,
    String? category,
  }) async {
    final result = await Navigator.push<AssistanceRequest>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RequestForm(existing: existing, defaultCategory: category),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      final index = requests.indexWhere((request) => request.id == result.id);

      if (index == -1) {
        requests.insert(0, result);
      } else {
        requests[index] = result;
      }
    });

    await saveRequests();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? 'Request added successfully.'
              : 'Request updated successfully.',
        ),
      ),
    );
  }

  Future<void> deleteRequest(AssistanceRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete request?'),
          content: Text('Delete the request for ${request.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      requests.removeWhere((item) => item.id == request.id);
    });

    await saveRequests();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request deleted successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Assistance Portal',
      'Assistance Requests',
      'Public Holidays',
      'About the Portal',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[selectedIndex])),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: selectedIndex,
              children: [
                dashboard(),
                requestList(),
                holidayPage(),
                aboutPage(),
              ],
            ),
      floatingActionButton: selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => openRequestForm(),
              icon: const Icon(Icons.add),
              label: const Text('New Request'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Holidays',
          ),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'About'),
        ],
      ),
    );
  }

  Widget dashboard() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.volunteer_activism,
                size: 42,
                color: Color(0xFF5EEAD4),
              ),
              SizedBox(height: 14),
              Text(
                'Everyone deserves accessible services.',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'A simple portal for organizing PWD and senior citizen assistance requests.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total Requests',
                count: '${requests.length}',
                icon: Icons.assignment,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Pending',
                count: '${requests.where((r) => r.status == 'Pending').length}',
                icon: Icons.hourglass_top,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Available Services',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ServiceTile(
          icon: Icons.accessible,
          title: 'PWD Assistance',
          subtitle: 'Support requests and accessibility needs',
          onTap: () => openRequestForm(category: 'PWD'),
        ),
        ServiceTile(
          icon: Icons.elderly,
          title: 'Senior Citizen Assistance',
          subtitle: 'Support requests for older adults',
          onTap: () => openRequestForm(category: 'Senior Citizen'),
        ),
        ServiceTile(
          icon: Icons.calendar_month,
          title: 'Philippine Public Holidays',
          subtitle: 'View holiday information retrieved online',
          onTap: () {
            setState(() {
              selectedIndex = 2;
            });
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'Recent Requests',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No requests yet. Create your first request.'),
            ),
          )
        else
          ...requests.take(3).map(requestCard),
      ],
    );
  }

  Widget requestList() {
    final filtered = requests.where((request) {
      final query = searchText.toLowerCase().trim();

      return request.name.toLowerCase().contains(query) ||
          request.service.toLowerCase().contains(query) ||
          request.category.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name, category, or service',
            ),
            onChanged: (value) {
              setState(() {
                searchText = value;
              });
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No matching assistance requests found.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return requestCard(filtered[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget requestCard(AssistanceRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: teal.withValues(alpha: 0.12),
                  child: Icon(
                    request.category == 'PWD'
                        ? Icons.accessible
                        : Icons.elderly,
                    color: teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text('${request.category} • ${request.service}'),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Request actions',
                  onSelected: (value) {
                    if (value == 'edit') {
                      openRequestForm(existing: request);
                    } else if (value == 'delete') {
                      deleteRequest(request);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Contact: ${request.contact}'),
            if (request.details.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Details: ${request.details}'),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(request.status),
                backgroundColor: request.status == 'Completed'
                    ? Colors.green.shade100
                    : request.status == 'In Progress'
                    ? Colors.blue.shade100
                    : Colors.orange.shade100,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget holidayPage() {
    if (loadingHolidays) {
      return const Center(child: CircularProgressIndicator());
    }

    if (holidayError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              Text(holidayError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: loadHolidays,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = [...holidays]
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Philippine Public Holidays • ${DateTime.now().year}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: sorted.isEmpty
              ? const Center(child: Text('No holiday data available.'))
              : ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final holiday = sorted[index];

                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.event)),
                      title: Text(
                        holiday['localName']?.toString() ?? 'Holiday',
                      ),
                      subtitle: Text(holiday['date']?.toString() ?? ''),
                      trailing: const Icon(Icons.public),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextButton.icon(
            onPressed: loadHolidays,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh API Data'),
          ),
        ),
      ],
    );
  }

  Widget aboutPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Icon(Icons.volunteer_activism, size: 72, color: teal),
        SizedBox(height: 16),
        Text(
          'PWD & Senior Citizen Assistance Portal',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text(
          'This educational application demonstrates a digital approach to organizing assistance requests for persons with disabilities and senior citizens.',
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24),
        Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project Features',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text('• Create, view, edit, and delete requests'),
                Text('• Local device storage'),
                Text('• Public holiday API integration'),
                Text('• Search and form validation'),
                Text('• Confirmation dialogs and feedback'),
                Text('• Mobile and web support'),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Demonstration project only. Requests are stored on this device and are not submitted to an LGU or government office.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class RequestForm extends StatefulWidget {
  final AssistanceRequest? existing;
  final String? defaultCategory;

  const RequestForm({super.key, this.existing, this.defaultCategory});

  @override
  State<RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<RequestForm> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final contactController = TextEditingController();
  final detailsController = TextEditingController();

  String category = 'PWD';
  String service = 'Financial Assistance';
  String status = 'Pending';

  final List<String> services = const [
    'Financial Assistance',
    'Medical Assistance',
    'Mobility Equipment',
    'Transportation Assistance',
    'Food Assistance',
    'Accessibility Support',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    if (existing != null) {
      nameController.text = existing.name;
      contactController.text = existing.contact;
      detailsController.text = existing.details;

      category = existing.category;
      service = services.contains(existing.service)
          ? existing.service
          : 'Other';
      status = ['Pending', 'In Progress', 'Completed'].contains(existing.status)
          ? existing.status
          : 'Pending';
    } else {
      category = widget.defaultCategory ?? 'PWD';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;

    final old = widget.existing;

    final result = AssistanceRequest(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      category: category,
      service: service,
      contact: contactController.text.trim(),
      details: detailsController.text.trim(),
      status: status,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'New Assistance Request' : 'Edit Request',
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.existing == null
                  ? 'Request Information'
                  : 'Update Request Information',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Complete the fields below.'),
            const SizedBox(height: 22),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Client Category'),
              items: const [
                DropdownMenuItem(
                  value: 'PWD',
                  child: Text('Person with Disability (PWD)'),
                ),
                DropdownMenuItem(
                  value: 'Senior Citizen',
                  child: Text('Senior Citizen'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    category = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name.';
                }

                if (value.trim().length < 2) {
                  return 'Name must contain at least 2 characters.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: contactController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                final contact = value?.trim() ?? '';

                if (contact.length < 7 ||
                    !RegExp(r'^[0-9+\-() ]+$').hasMatch(contact)) {
                  return 'Enter a valid contact number.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: service,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Service Needed'),
              items: services.map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    service = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Request Status'),
              items: const [
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(
                  value: 'In Progress',
                  child: Text('In Progress'),
                ),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    status = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: detailsController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Additional Details (Optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: submit,
                icon: const Icon(Icons.save_outlined),
                label: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.existing == null ? 'Save Request' : 'Update Request',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: teal, size: 28),
            const SizedBox(height: 12),
            Text(
              count,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class ServiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ServiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: teal.withValues(alpha: 0.12),
          child: Icon(icon, color: teal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
