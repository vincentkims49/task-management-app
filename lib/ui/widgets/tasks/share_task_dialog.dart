import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/task.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/tasks/task_sharing_service.dart';
import '../../theme/theme_constants.dart';

class ShareTaskDialog extends StatefulWidget {
  final Task task;

  const ShareTaskDialog({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  State<ShareTaskDialog> createState() => _ShareTaskDialogState();
}

class _ShareTaskDialogState extends State<ShareTaskDialog> {
  final _emailController = TextEditingController();
  bool _isSearching = false;
  List<UserProfile> _searchResults = [];
  final List<UserProfile> _selectedUsers = [];
  bool _isSharingInProgress = false;
  String? _errorMessage;
  List<String> _alreadySharedWith = [];

  late final UserRepository _userRepository;
  late final TaskSharingService _taskSharingService;

  @override
  void initState() {
    super.initState();
    _userRepository = context.read<UserRepository>();
    _taskSharingService = context.read<TaskSharingService>();

    _initAlreadyShared();
  }

  Future<void> _initAlreadyShared() async {
    _alreadySharedWith = widget.task.sharedWith;

    if (_alreadySharedWith.isNotEmpty) {
      setState(() {
        _isSearching = true;
      });

      try {
        for (final userId in _alreadySharedWith) {
          final userProfile = await _userRepository.getUserById(userId);
          if (userProfile != null) {
            setState(() {
              _selectedUsers.add(userProfile);
            });
          }
        }
      } finally {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share Task',
              style: AppTextStyles.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              widget.task.title,
              style: AppTextStyles.body1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.paddingL),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Search by email',
                hintText: 'Enter user email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _emailController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _emailController.clear();
                            _searchResults.clear();
                          });
                        },
                      )
                    : null,
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: _searchUsers,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else if (_searchResults.isNotEmpty) ...[
              Text(
                'Search Results',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppDimensions.paddingS),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final isAlreadyShared =
                        _alreadySharedWith.contains(user.id);
                    final isSelected = _selectedUsers.contains(user);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryColor,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title:
                          Text(user.name, style: const TextStyle(fontSize: 16)),
                      subtitle: Text(user.email),
                      trailing: isAlreadyShared
                          ? const Chip(
                              label: Text('Already shared'),
                              backgroundColor: Colors.grey,
                            )
                          : Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedUsers.add(user);
                                  } else {
                                    _selectedUsers.remove(user);
                                  }
                                });
                              },
                            ),
                      enabled: !isAlreadyShared,
                    );
                  },
                ),
              ),
            ] else if (_emailController.text.isNotEmpty) ...[
              const Text(
                'No users found',
                style: TextStyle(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
            if (_selectedUsers.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.paddingM),
              Text(
                'Selected Users',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Wrap(
                spacing: AppDimensions.paddingS,
                children: _selectedUsers.map((user) {
                  final isAlreadyShared = _alreadySharedWith.contains(user.id);
                  return Chip(
                    label: Text(user.name),
                    backgroundColor: isAlreadyShared
                        ? Colors.grey[300]
                        : AppColors.primaryColor.withOpacity(0.2),
                    deleteIcon:
                        isAlreadyShared ? null : const Icon(Icons.close),
                    onDeleted: isAlreadyShared
                        ? null
                        : () {
                            setState(() {
                              _selectedUsers.remove(user);
                            });
                          },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: AppDimensions.paddingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: _isSharingInProgress
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSharingInProgress || _newSelectedUsers.isEmpty
                      ? null
                      : _shareTask,
                  child: _isSharingInProgress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<UserProfile> get _newSelectedUsers => _selectedUsers
      .where((user) => !_alreadySharedWith.contains(user.id))
      .toList();

  Future<void> _searchUsers(String email) async {
    if (email.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await _userRepository.searchUsersByEmail(email);

      if (!mounted) return;

      setState(() {
        _searchResults = results;

        if (results.isEmpty) {
          _errorMessage = 'No users found matching this email';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error searching for users: ${e.toString()}';
        _searchResults.clear();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _shareTask() async {
    setState(() {
      _isSharingInProgress = true;
      _errorMessage = null;
    });

    try {
      for (final user in _newSelectedUsers) {
        await _taskSharingService.shareTaskWithUser(widget.task.id, user.email);
      }

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isSharingInProgress = false;
      });
    }
  }
}
