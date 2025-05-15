import 'package:flutter/material.dart';

import 'class_page.dart';
import 'skill_pages.dart';

class ClassSkillsContainer extends StatefulWidget {
  final int initialPage; // 0 for Class page, 1 for Skill page

  const ClassSkillsContainer({Key? key, this.initialPage = 0}) : super(key: key);

  @override
  _ClassSkillsContainerState createState() => _ClassSkillsContainerState();
}

class _ClassSkillsContainerState extends State<ClassSkillsContainer> {
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPage == 0 ? 'Skill Tree' : 'Classes'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          // Return to profile page
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Switch between pages button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _currentPage = _currentPage == 0 ? 1 : 0;
              });
            },
            icon: Icon(
              _currentPage == 0 ? Icons.class_ : Icons.account_tree,
              color: Colors.white,
            ),
            label: Text(
              _currentPage == 0 ? 'Classes' : 'Skill Tree',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _currentPage == 0 ? SkillsPage() : ClassPage(),
    );
  }
}