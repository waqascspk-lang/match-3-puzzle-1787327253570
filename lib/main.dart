import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Tile {
  final String id;
  final int row;
  final int col;
  final String type;
  final bool isSelected;

  Tile({
    this.id = '',
    this.row = 0,
    this.col = 0,
    this.type = '',
    this.isSelected = false,
  });

  Tile copyWith({
    String? id,
    int? row,
    int? col,
    String? type,
    bool? isSelected,
  }) {
    return Tile(
      id: id ?? this.id,
      row: row ?? this.row,
      col: col ?? this.col,
      type: type ?? this.type,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  factory Tile.fromJson(Map<String, dynamic> json) {
    return Tile(
      id: json['id'] ?? '',
      row: json['row'] ?? 0,
      col: json['col'] ?? 0,
      type: json['type'] ?? '',
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'row': row,
      'col': col,
      'type': type,
      'isSelected': isSelected,
    };
  }
}

class GameProvider extends ChangeNotifier {
  int currentLevel = 0;
  int score = 0;
  int movesLeft = 0;
  int targetScore = 0;
  List<List<Tile>> grid = [];
  Tile? selectedTile;

  final Map<int, Map<String, dynamic>> levelConfigs = {
    0: {'target': 100, 'moves': 15, 'types': ['🍬', '🍭', '🍩']},
    1: {'target': 150, 'moves': 12, 'types': ['🍬', '🍭', '🍩', '🍫']},
    2: {'target': 200, 'moves': 10, 'types': ['🍬', '🍭', '🍩', '🍫']},
    3: {'target': 250, 'moves': 10, 'types': ['🍬', '🍭', '🍩', '🍫', '🧁']},
    4: {'target': 300, 'moves': 8, 'types': ['🍬', '🍭', '🍩', '🍫', '🧁']},
  };

  void startLevel(int index) {
    currentLevel = index;
    final config = levelConfigs[index]!;
    targetScore = config['target'];
    movesLeft = config['moves'];
    score = 0;
    selectedTile = null;
    _initializeGrid(List<String>.from(config['types']));
    notifyListeners();
  }

  void _initializeGrid(List<String> types) {
    grid = List.generate(6, (r) => List.generate(6, (c) => Tile(row: r, col: c)));

    for (int r = 0; r < 6; r++) {
      for (int c = 0; c < 6; c++) {
        List<String> validTypes = types.where((t) => !_wouldCreateMatch(r, c, t)).toList();
        String selectedType = validTypes.isNotEmpty
            ? (validTypes..shuffle()).first
            : (List<String>.from(types)..shuffle()).first;

        grid[r][c] = Tile(
          id: '${r}_$c',
          row: r,
          col: c,
          type: selectedType,
        );
      }
    }
  }

  bool _wouldCreateMatch(int r, int c, String type) {
    if (r >= 2 && grid[r - 1][c].type == type && grid[r - 2][c].type == type) return true;
    if (c >= 2 && grid[r][c - 1].type == type && grid[r][c - 2].type == type) return true;
    return false;
  }

  void tapTile(int r, int c) {
    if (movesLeft <= 0 || score >= targetScore) return;

    Tile tappedTile = grid[r][c];

    if (selectedTile == null) {
      selectedTile = tappedTile;
      grid[r][c] = tappedTile.copyWith(isSelected: true);
    } else {
      int r1 = selectedTile!.row;
      int c1 = selectedTile!.col;

      grid[r1][c1] = grid[r1][c1].copyWith(isSelected: false);

      if ((r1 - r).abs() + (c1 - c).abs() == 1) {
        _swapTiles(r1, c1, r, c);
        if (checkAndClearMatches()) {
          movesLeft--;
          _processCascades();
        } else {
          _swapTiles(r1, c1, r, c);
        }
      }
      selectedTile = null;
    }
    notifyListeners();
  }

  void _swapTiles(int r1, int c1, int r2, int c2) {
    Tile t1 = grid[r1][c1];
    Tile t2 = grid[r2][c2];
    grid[r1][c1] = t2.copyWith(row: r1, col: c1);
    grid[r2][c2] = t1.copyWith(row: r2, col: c2);
  }

  bool checkAndClearMatches() {
    Set<String> matchedIds = {};

    for (int r = 0; r < 6; r++) {
      for (int c = 0; c < 4; c++) {
        if (grid[r][c].type != 'EMPTY' &&
            grid[r][c].type == grid[r][c + 1].type &&
            grid[r][c].type == grid[r][c + 2].type) {
          matchedIds.addAll(['${r}_$c', '${r}_${c + 1}', '${r}_${c + 2}']);
        }
      }
    }

    for (int c = 0; c < 6; c++) {
      for (int r = 0; r < 4; r++) {
        if (grid[r][c].type != 'EMPTY' &&
            grid[r][c].type == grid[r + 1][c].type &&
            grid[r][c].type == grid[r + 2][c].type) {
          matchedIds.addAll(['${r}_$c', '${r + 1}_$c', '${r + 2}_$c']);
        }
      }
    }

    if (matchedIds.isEmpty) return false;

    score += matchedIds.length * 10;
    for (int r = 0; r < 6; r++) {
      for (int c = 0; c < 6; c++) {
        if (matchedIds.contains('${r}_$c')) {
          grid[r][c] = grid[r][c].copyWith(type: 'EMPTY');
        }
      }
    }
    return true;
  }

  void _processCascades() {
    int maxCascadeDepth = 10;
    while (maxCascadeDepth > 0) {
      dropAndRefill();
      if (!checkAndClearMatches()) break;
      maxCascadeDepth--;
    }
  }

  void dropAndRefill() {
    final types = List<String>.from(levelConfigs[currentLevel]!['types']);

    for (int c = 0; c < 6; c++) {
      List<String> columnTypes = [];
      for (int r = 5; r >= 0; r--) {
        if (grid[r][c].type != 'EMPTY') {
          columnTypes.add(grid[r][c].type);
        }
      }

      while (columnTypes.length < 6) {
        columnTypes.add((List<String>.from(types)..shuffle()).first);
      }

      for (int r = 5; r >= 0; r--) {
        grid[r][c] = grid[r][c].copyWith(type: columnTypes[5 - r]);
      }
    }
  }

  void restartLevel() => startLevel(currentLevel);

  void nextLevel() {
    if (currentLevel < levelConfigs.length - 1) {
      startLevel(currentLevel + 1);
    }
  }
}

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Candy Match Levels',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: provider.levelConfigs.length,
            itemBuilder: (context, index) {
              final config = provider.levelConfigs[index]!;
              final target = config['target'];

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  title: Text(
                    'Level ${index + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Target Score: $target pts',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.play_arrow,
                    size: 32,
                    color: Colors.blue,
                  ),
                  onTap: () {
                    provider.startLevel(index);
                    Navigator.pushNamed(context, '/gamePlay');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  bool _dialogShowing = false;

  void _showResultDialog(BuildContext context, bool won) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            won ? 'Level Passed!' : 'Out of Moves!',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            won
                ? 'Congratulations! You reached the target score.'
                : 'You ran out of moves before hitting the target.',
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<GameProvider>().restartLevel();
                _dialogShowing = false;
              },
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            if (won)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.read<GameProvider>().nextLevel();
                  _dialogShowing = false;
                },
                child: const Text('Next Level', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/');
                _dialogShowing = false;
              },
              child: const Text('Exit', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        if (!_dialogShowing) {
          if (provider.score >= provider.targetScore) {
            _dialogShowing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showResultDialog(context, true);
            });
          } else if (provider.movesLeft <= 0) {
            _dialogShowing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showResultDialog(context, false);
            });
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Level ${provider.currentLevel + 1}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Target', provider.targetScore.toString()),
                    _buildStatColumn('Score', provider.score.toString()),
                    _buildStatColumn('Moves', provider.movesLeft.toString()),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 36,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemBuilder: (context, index) {
                          int r = index ~/ 6;
                          int c = index % 6;
                          Tile tile = provider.grid[r][c];

                          return GestureDetector(
                            onTap: () => provider.tapTile(r, c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: tile.isSelected
                                    ? Colors.blue.withAlpha(76)
                                    : Colors.grey.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: tile.isSelected ? Colors.blue : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  tile.type == 'EMPTY' ? '' : tile.type,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => GameProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Match-3 Puzzle',
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const LevelSelectScreen());
        }
        if (settings.name == '/gamePlay') {
          return MaterialPageRoute(builder: (context) => const GamePlayScreen());
        }
        return null;
      },
    );
  }
}
