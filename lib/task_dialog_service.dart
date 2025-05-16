import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'task_page.dart';


class TaskDialogService {
  // Shows Task Editor Dialog
  static void showEditTaskDialog(BuildContext context, Map<String, dynamic> task) {

    // Controllers for text fields
    TextEditingController titleController = TextEditingController(text: task['title']);
    TextEditingController descController = TextEditingController(text: task['description'] ?? '');

    // Populate Dropdown and toggle button fields
    String selectedType = task['type'];
    String selectedCategory = task['category'];
    String selectedDifficulty = task['difficulty'];
    DateTime? dueDate;
    if (task['dueDate'] != null) {
      dueDate = DateTime.tryParse(task['dueDate']);
    } else {
      dueDate = null;
    }
    bool showError = false;
    bool isCompleted = task['completed'] == true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(

              // Change title to 'View Task' if task completed
              title: Text(isCompleted ? 'View Task' : 'Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // Task Title
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Task Name',
                        errorText: showError && titleController.text.isEmpty
                            ? 'Required'
                            : null,
                      ),
                      enabled: !isCompleted,// Disable if task is completed
                    ),

                    // Description
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(labelText: 'Description (Optional)'),
                      enabled: !isCompleted,// Disable if task is completed
                    ),

                    // Task Type Dropdown
                    DropdownButtonFormField(
                      value: selectedType,
                      items: ['Daily', 'Weekly', 'Monthly', 'One-Time']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),

                      // Disable dropdown if task completed
                      onChanged: isCompleted
                          ? null
                          : (value) {
                        setDialogState(() {
                          selectedType = value as String;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Type'),
                    ),

                    // Task Category Dropdown
                    DropdownButtonFormField(
                      value: selectedCategory,
                      items: ['Physical', 'Intellectual', 'Academic', 'Lifestyle', 'Miscellaneous']
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      // Disable dropdown if task completed
                      onChanged: isCompleted
                          ? null
                          : (value) {
                        setDialogState(() {
                          selectedCategory = value as String;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Category'),
                    ),

                    // Task Difficulty 3-way toggle button
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: ToggleButtons(
                        isSelected: [
                          selectedDifficulty == 'Easy',
                          selectedDifficulty == 'Medium',
                          selectedDifficulty == 'Hard',
                        ],
                        // Disable button if task completed
                        onPressed: isCompleted
                            ? null
                            : (int index) {
                          setDialogState(() {
                            selectedDifficulty = ['Easy', 'Medium', 'Hard'][index];
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        selectedColor: Colors.white,
                        fillColor: Colors.deepPurple,
                        color: Colors.grey,
                        children: [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Easy')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Medium')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Hard')),
                        ],
                      ),
                    ),

                    // If type is 'One-Time' show due date picker
                    if (selectedType == 'One-Time')
                      isCompleted
                          ? Text(
                        dueDate == null ? 'No Due Date' : 'Due Date: ${DateFormat.yMMMd().format(dueDate!)}',
                        style: TextStyle(fontSize: 16, height: 2),
                      )
                          : TextButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day); // midnight today

                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: today,
                            firstDate: today,
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
                          }
                        },
                        child: Text(dueDate == null
                            ? 'Pick Due Date'
                            : DateFormat.yMMMd().format(dueDate!)),
                      ),
                    if (showError && selectedType == 'One-Time' && dueDate == null && !isCompleted)
                      Text('Due Date is required', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),

              // Close Button
              actions: [
                TextButton(
                  child: Text('Close'),
                  onPressed: () => Navigator.pop(context),
                ),

                // Only show Delete and Save buttons for ongoing tasks
                if (!isCompleted)
                  TextButton(
                    child: Text('Delete'),
                    onPressed: () {
                      Provider.of<TaskProvider>(context, listen: false).deleteTask(task['id']);
                      Navigator.pop(context);
                    },
                  ),
                if (!isCompleted)
                  TextButton(
                    child: Text('Save'),
                    onPressed: () {
                      if (titleController.text.isEmpty) {
                        setDialogState(() => showError = true);
                      } else {
                        Provider.of<TaskProvider>(context, listen: false).editTask(
                          task['id'],
                          titleController.text,
                          descController.text,
                          selectedType,
                          selectedCategory,
                          selectedDifficulty,
                          dueDate,
                        );
                        Navigator.pop(context);
                      }
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}