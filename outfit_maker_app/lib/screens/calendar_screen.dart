import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/outfit.dart';
import '../services/outfit_service.dart';
import '../services/calendar_outfit_service.dart';
import '../services/weather_service.dart';
import '../ai/outfit_ai.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final OutfitService _outfitService = OutfitService();
  final CalendarOutfitService _calendarService = CalendarOutfitService();
  final WeatherService _weatherService = WeatherService();
  final OutfitAI _outfitAI = OutfitAI();

  List<Outfit> _savedOutfits = [];
  bool _isLoading = true;
  double? _currentTemperature;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initialize();
  }

  Future<void> _initialize() async {
    await _outfitService.initialize();
    await _calendarService.initialize();

    setState(() {
      _savedOutfits = _outfitService.getAllOutfits();
      _isLoading = false;
    });

    // Cargar temperatura actual
    _loadTemperature();
  }

  Future<void> _loadTemperature() async {
    if (_weatherService.isConfigured) {
      final temp = await _weatherService.getCurrentLocationTemperature();
      if (mounted) {
        setState(() => _currentTemperature = temp);
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    _savedOutfits = _outfitService.getAllOutfits();
    setState(() => _isLoading = false);
  }

  void _addOutfitForDay(DateTime day) {
    if (_savedOutfits.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin outfits guardados'),
          content: const Text('Primero debes crear y guardar outfits en el creador de outfits.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seleccionar outfit para ${_formatDate(day)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.auto_awesome),
                      tooltip: 'Sugerir outfit',
                      onPressed: () => _suggestOutfitForDay(day),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _savedOutfits.length,
                    itemBuilder: (context, index) {
                      final outfit = _savedOutfits[index];
                      final isPlanned = _calendarService.getPlannedOutfitForDate(day)?.outfitId == outfit.id;

                      return Card(
                        color: isPlanned ? Colors.blue.shade50 : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPlanned ? Colors.blue : Colors.grey,
                            child: Text('${outfit.clothes.length}'),
                          ),
                          title: Text(outfit.name),
                          subtitle: Text('${outfit.clothes.length} prendas'),
                          trailing: isPlanned
                              ? const Icon(Icons.check_circle, color: Colors.blue)
                              : const Icon(Icons.add_circle_outline),
                          onTap: () async {
                            await _calendarService.planOutfit(
                              outfitId: outfit.id,
                              date: day,
                            );
                            Navigator.pop(context);
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _suggestOutfitForDay(DateTime day) async {
    // Obtener prendas del armario
    final clothes = _savedOutfits.expand((o) => o.clothes).toList();

    if (clothes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay prendas disponibles')),
      );
      return;
    }

    // Sugerir outfit basado en temperatura
    final suggestion = _outfitAI.suggestOutfit(
      clothes,
      temperature: _currentTemperature,
    );

    if (suggestion.isEmpty) return;

    // Crear outfit temporal
    final tempOutfit = Outfit(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Sugerencia para ${_formatDate(day)}',
      clothes: suggestion,
      createdAt: DateTime.now(),
    );

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Outfit Sugerido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_outfitAI.generateOutfitExplanation(
              suggestion,
              temperature: _currentTemperature,
            )),
            const SizedBox(height: 16),
            ...suggestion.map((item) => ListTile(
              leading: const Icon(Icons.checkroom),
              title: Text(item.name),
              dense: true,
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usar este outfit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Guardar outfit y planificar
      final saved = await _outfitService.saveOutfit(
        name: tempOutfit.name,
        clothes: suggestion,
      );

      await _calendarService.planOutfit(
        outfitId: saved.id,
        date: day,
      );

      await _refreshData();
    }
  }

  Future<void> _showOutfitDetails(PlannedOutfit planned) async {
    final outfit = _outfitService.getOutfitById(planned.outfitId);
    if (outfit == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outfit.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Planificado para: ${_formatDate(planned.date)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (planned.notes != null) ...[
              const SizedBox(height: 8),
              Text('Notas: ${planned.notes}'),
            ],
            const SizedBox(height: 16),
            const Text(
              'Prendas:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...outfit.clothes.map((item) => ListTile(
              leading: const Icon(Icons.checkroom),
              title: Text(item.name),
              subtitle: Text('${item.category} • Talla ${item.size}'),
              dense: true,
            )),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _calendarService.markAsCompleted(
                        planned.id,
                        completed: !planned.isCompleted,
                      );
                      Navigator.pop(context);
                      setState(() {});
                    },
                    icon: Icon(planned.isCompleted ? Icons.undo : Icons.check),
                    label: Text(planned.isCompleted ? 'Desmarcar' : 'Usado'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _calendarService.removePlannedOutfit(planned.id);
                      Navigator.pop(context);
                      setState(() {});
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Calendario de Outfits"),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'auto') {
                await _calendarService.planWeekAutomatically(_savedOutfits);
                setState(() {});
              } else if (value == 'clear') {
                await _calendarService.clearAllPlannedOutfits();
                setState(() {});
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'auto',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome),
                    SizedBox(width: 8),
                    Text('Planificar semana'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Limpiar todo', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: (day) {
              final planned = _calendarService.getPlannedOutfitForDate(day);
              return planned != null ? [planned] : [];
            },
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.blue.shade300,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.orange.shade300,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text('Selecciona un día'))
                : _buildOutfitList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedDay != null
            ? () => _addOutfitForDay(_selectedDay!)
            : null,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOutfitList() {
    final planned = _selectedDay != null
        ? _calendarService.getPlannedOutfitForDate(_selectedDay!)
        : null;

    if (planned == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No hay outfits planificados para ${_formatDate(_selectedDay!)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _addOutfitForDay(_selectedDay!),
              icon: const Icon(Icons.add),
              label: const Text('Añadir Outfit'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _suggestOutfitForDay(_selectedDay!),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Sugerir Outfit'),
            ),
          ],
        ),
      );
    }

    final outfit = _outfitService.getOutfitById(planned.outfitId);
    if (outfit == null) {
      return const Center(
        child: Text('Outfit no encontrado'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: planned.isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: planned.isCompleted ? Colors.green : Colors.blue,
              child: Icon(
                planned.isCompleted ? Icons.check : Icons.checkroom,
                color: Colors.white,
              ),
            ),
            title: Text(outfit.name),
            subtitle: Text(
              '${outfit.clothes.length} prendas${planned.isCompleted ? ' • Usado' : ''}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showOutfitDetails(planned),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Prendas del outfit:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...outfit.clothes.map((item) => Card(
          child: ListTile(
            leading: const Icon(Icons.checkroom),
            title: Text(item.name),
            subtitle: Text('${item.category} • Talla ${item.size}'),
          ),
        )),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
