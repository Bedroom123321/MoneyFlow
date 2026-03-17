import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/category.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Category> _incomeCategories = [];
  List<Category> _expenseCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final income =
    await DatabaseHelper.instance.getAllCategories(type: 'income');
    final expense =
    await DatabaseHelper.instance.getAllCategories(type: 'expense');
    setState(() {
      _incomeCategories = income;
      _expenseCategories = expense;
      _isLoading = false;
    });
  }

  Future<void> _showCategoryDialog({Category? category, required String type}) async {
    final isEdit = category != null;
    final controller =
    TextEditingController(text: category?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Редактировать категорию' : 'Новая категория'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите название категории';
                }
                if (value.trim().length > 30) {
                  return 'Максимум 30 символов';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final name = controller.text.trim();
                if (isEdit) {
                  final updated = category!.copyWith(name: name);
                  await DatabaseHelper.instance.updateCategory(updated);
                } else {
                  final newCategory = Category(
                    name: name,
                    type: type,
                    icon: 'default',
                  );
                  await DatabaseHelper.instance.createCategory(newCategory);
                }
                if (context.mounted) Navigator.pop(context, true);
              },
              child: Text(isEdit ? 'Сохранить' : 'Создать'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _loadCategories();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить категорию?'),
          content: Text('Категория "${category.name}" будет удалена.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Удалить',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteCategory(category.id!);
      _loadCategories();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Доходы'),
            Tab(text: 'Расходы'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final type =
          _tabController.index == 0 ? 'income' : 'expense';
          _showCategoryDialog(type: type);
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildList(_incomeCategories, 'income'),
          _buildList(_expenseCategories, 'expense'),
        ],
      ),
    );
  }

  Widget _buildList(List<Category> categories, String type) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          type == 'income'
              ? 'Категории доходов пока не созданы'
              : 'Категории расходов пока не созданы',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          child: ListTile(
            title: Text(category.name),
            leading: Icon(
              type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
              color: type == 'income' ? Colors.green : Colors.red,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () =>
                      _showCategoryDialog(category: category, type: type),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.red),
                  onPressed: () => _deleteCategory(category),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
