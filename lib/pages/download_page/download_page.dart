import 'package:flutter/material.dart';
import '../services/instance_manager.dart';
import './viewmodels/download_page_viewmodel.dart';
import './components/task_list_item.dart';
import './components/filter_selector.dart';
import './components/task_details_dialog.dart';

class DownloadPage extends StatefulWidget {
  final InstanceManager instanceManager;

  const DownloadPage({Key? key, required this.instanceManager}) : super(key: key);

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final DownloadPageViewModel _viewModel = DownloadPageViewModel();
  List<String> _selectedTaskIds = [];

  @override
  void initState() {
    super.initState();
    _viewModel.initialize(widget.instanceManager);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Implementation will be added later
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
      ),
      body: const Center(
        child: Text('Download Page Content'),
      ),
    );
  }
}