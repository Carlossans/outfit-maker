import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/app_services.dart';

/// Pantalla de calendario simplificada para planificar outfits
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final OutfitService _outfitService = OutfitService();

  DateTime _selectedDay = DateTime.now();
  List<Outfit> _savedOutfits = [];
  bool _isLoading = true;

  // Mapa simple de fecha -> outfit planificado (en memoria)
  final Map<String, Outfit> _plannedOutfits = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _outfitService.initialize();

    setState(() {
      _savedOutfits = _outfitService.getAllOutfits();
      _isLoading = false;
    });
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  void _addOutfitForDay(DateTime day) {
    if (_savedOutfits.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin outfits guardados'),
          content: const Text(
              'Primero debes crear y guardar outfits en el creador de outfits.'),
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
                Text(
                  'Seleccionar outfit para ${_formatDate(day)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _savedOutfits.length,
                    itemBuilder: (context, index) {
                      final outfit = _savedOutfits[index];
                      final isPlanned = _plannedOutfits[_getDateKey(day)]?.id == outfit.id;

                      return Card(
                        color: isPlanned ? Colors.blue.shade50 : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isPlanned ? Colors.blue : Colors.grey,
                            child: Text('${outfit.items.length}'),
                          ),
                          title: Text(outfit.name),
                          subtitle: Text('${outfit.items.length} prendas'),
                          trailing: isPlanned
                              ? const Icon(Icons.check_circle, color: Colors.blue)
                              : const Icon(Icons.add_circle_outline),
                          onTap: () {
                            setState(() {
                              if (isPlanned) {
                                _plannedOutfits.remove(_getDateKey(day));
                              } else {
                                _plannedOutfits[_getDateKey(day)] = outfit;
                              }
                            });
                            Navigator.pop(context);
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

  void _clearPlannedOutfits() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar calendario'),
        content: const Text('¿Eliminar todos los outfits planificados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _plannedOutfits.clear());
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar todo'),
          ),
        ],
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
        title: const Text('Calendario de Outfits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearPlannedOutfits,
            tooltip: 'Limpiar todo',
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendario mensual simplificado
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header con mes y navegación
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDay = DateTime(
                            _selectedDay.year,
                            _selectedDay.month - 1,
                            _selectedDay.day,
                          );
                        });
                      },
                    ),
                    Text(
                      _getMonthName(_selectedDay.month) + ' ${_selectedDay.year}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _selectedDay = DateTime(
                            _selectedDay.year,
                            _selectedDay.month + 1,
                            _selectedDay.day,
                          );
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Días de la semana
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Text('Lun', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Mar', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Mié', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Jue', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Vie', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Sáb', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Dom', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),

                // Días del mes
                _buildCalendarDays(),
              ],
            ),
          ),

          const Divider(),

          // Outfit planificado para el día seleccionado
          Expanded(
            child: _buildSelectedDayOutfit(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOutfitForDay(_selectedDay),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendarDays() {
    final daysInMonth = _getDaysInMonth(_selectedDay.year, _selectedDay.month);
    final firstWeekday = DateTime(_selectedDay.year, _selectedDay.month, 1).weekday;

    final today = DateTime.now();

    List<Widget> dayWidgets = [];

    // Espacios en blanco para los días antes del primer día del mes
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox.shrink());
    }

    // Días del mes
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedDay.year, _selectedDay.month, day);
      final dateKey = _getDateKey(date);
      final isSelected = _selectedDay.day == day;
      final hasOutfit = _plannedOutfits.containsKey(dateKey);
      final isToday = today.day == day &&
          today.month == _selectedDay.month &&
          today.year == _selectedDay.year;

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDay = date;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : isToday
                      ? Colors.orange.shade200
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (hasOutfit)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1,
      children: dayWidgets,
    );
  }

  Widget _buildSelectedDayOutfit() {
    final plannedOutfit = _plannedOutfits[_getDateKey(_selectedDay)];

    if (plannedOutfit == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No hay outfits planificados para ${_formatDate(_selectedDay)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _addOutfitForDay(_selectedDay),
              icon: const Icon(Icons.add),
              label: const Text('Añadir Outfit'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outfit planificado:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text('${plannedOutfit.items.length}'),
              ),
              title: Text(plannedOutfit.name),
              subtitle: Text('${plannedOutfit.items.length} prendas'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _plannedOutfits.remove(_getDateKey(_selectedDay));
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Prendas del outfit:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: plannedOutfit.items.map((item) {
                return Card(
                  child: ListTile(
                    leading: Text(item.category.icon),
                    title: Text(item.name),
                    subtitle: Text(item.category.displayName),
                    dense: true,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month - 1];
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
