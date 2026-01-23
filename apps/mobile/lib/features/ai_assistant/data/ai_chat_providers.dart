import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ai/ai_providers.dart';
import '../../dashboard/data/user_profile_provider.dart';
import '../../projects/data/projects_provider.dart';
import '../../tasks/data/tasks_provider.dart';
import '../domain/models/ai_position.dart';
import '../domain/models/chat_conversation.dart';
import '../domain/models/chat_message.dart';
import 'ai_chat_repository.dart';

// =============================================================================
// POSITION STATE
// =============================================================================

/// Notifier for managing AI assistant bubble position
class AiPositionNotifier extends legacy.StateNotifier<AiPosition> {
  AiPositionNotifier() : super(AiPosition.defaultPosition()) {
    _loadPosition();
  }

  static const _prefsKey = 'ai_assistant.position';
  SharedPreferences? _prefs; // Cached instance
  Timer? _saveDebounce;

  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _loadPosition() async {
    try {
      final prefs = await _ensurePrefs();
      final json = prefs.getString(_prefsKey);
      if (json != null && mounted) {
        state = AiPosition.fromJson(json);
      }
    } catch (e, st) {
      // Use default position on error
      developer.log('AiPositionNotifier load position failed',
          error: e, stackTrace: st, name: 'AiPositionNotifier._loadPosition');
    }
  }

  Future<void> updatePosition(AiPosition position) async {
    state = position;
    // Debounce saves to avoid blocking UI on rapid updates
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final prefs = await _ensurePrefs();
        await prefs.setString(_prefsKey, state.toJson());
      } catch (e, st) {
        // Ignore save errors
        developer.log('AiPositionNotifier save position debounced failed',
            error: e, stackTrace: st, name: 'AiPositionNotifier.updatePosition');
      }
    });
  }

  void toggleExpanded() {
    state = state.copyWith(isExpanded: !state.isExpanded);
    _savePositionNow();
  }

  void setExpanded(bool expanded) {
    if (state.isExpanded != expanded) {
      state = state.copyWith(isExpanded: expanded);
      _savePositionNow();
    }
  }

  Future<void> _savePositionNow() async {
    _saveDebounce?.cancel();
    try {
      final prefs = await _ensurePrefs();
      await prefs.setString(_prefsKey, state.toJson());
    } catch (e, st) {
      // Ignore save errors
      developer.log('AiPositionNotifier save position now failed',
          error: e, stackTrace: st, name: 'AiPositionNotifier._savePositionNow');
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}

/// Provider for AI assistant position state
final aiPositionProvider = legacy.StateNotifierProvider<AiPositionNotifier, AiPosition>(
  (ref) => AiPositionNotifier(),
);

// =============================================================================
// CHAT REPOSITORY
// =============================================================================

/// Provider for the AI chat repository
final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return AiChatRepository(Supabase.instance.client);
});

// =============================================================================
// CONTEXT CACHE
// =============================================================================

/// Cached context data for AI prompts with 5-minute TTL
class _AiContextCache {
  static const _cacheDuration = Duration(minutes: 5);

  DateTime? _lastFetch;
  String? _cachedContext;

  bool get _shouldRefresh {
    if (_lastFetch == null || _cachedContext == null) return true;
    return DateTime.now().difference(_lastFetch!) > _cacheDuration;
  }

  /// Get cached context or fetch fresh
  Future<String> getContext(Ref ref) async {
    if (!_shouldRefresh) return _cachedContext!;

    final contextParts = <String>[];
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final formatter = DateFormat('MMM d, yyyy');

    if (user == null) {
      _cachedContext = '';
      _lastFetch = DateTime.now();
      return '';
    }

    // User info
    try {
      final profile = await ref.read(userProfileProvider.future);
      contextParts.add('User ID: ${profile.id}');
      final email = profile.email;
      if (email != null) {
        contextParts.add('Email: $email');
      }
      final orgId = profile.orgId;
      if (orgId != null) {
        contextParts.add('Organization ID: $orgId');
      }

      // Get role
      final roleRes = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final roleStr = roleRes?['role']?.toString() ?? 'viewer';
      contextParts.add('Role: $roleStr');
    } catch (e) {
      contextParts.add('User: ${user.email ?? "Unknown"}');
    }

    // Get projects
    try {
      final projects = await ref.read(projectsProvider.future);
      contextParts.add('Projects: ${projects.length}');
      if (projects.isNotEmpty) {
        final lines = projects.take(5).map((project) {
          final metadata = project.metadata ?? const <String, dynamic>{};
          final rawDue = metadata['dueDate'] ?? metadata['due_date'] ?? metadata['due'];
          DateTime? dueDate;
          if (rawDue is String) {
            dueDate = DateTime.tryParse(rawDue);
          } else if (rawDue is DateTime) {
            dueDate = rawDue;
          }
          final dueLabel = dueDate == null ? '' : ' (due ${formatter.format(dueDate)})';
          return '- ${project.name} [${project.status}]$dueLabel';
        }).join('\n');
        contextParts.add('Recent Projects:\n$lines');
      }
    } catch (e) {
      contextParts.add('Projects: Unable to load');
    }

    // Get tasks
    try {
      final tasks = await ref.read(tasksProvider.future);
      final activeTasks = tasks.where((t) => !t.isComplete).toList();
      contextParts.add('Active Tasks: ${activeTasks.length}');
      if (activeTasks.isNotEmpty && activeTasks.length <= 5) {
        final taskList = activeTasks
            .map((t) =>
                '- ${t.title}${t.dueDate != null ? " (due ${formatter.format(t.dueDate!.toLocal())})" : ""} [${t.status.name}]')
            .join('\n');
        contextParts.add('Current Tasks:\n$taskList');
      } else if (activeTasks.length > 5) {
        final topTasks = activeTasks.take(5).map((t) => t.title).join(', ');
        contextParts.add('Recent Tasks: $topTasks, and ${activeTasks.length - 5} more');
      }
    } catch (e) {
      contextParts.add('Tasks: Unable to load');
    }

    // Get work orders
    try {
      final workOrderProfile = await ref.read(userProfileProvider.future);
      final workOrderOrgId = workOrderProfile.orgId;
      if (workOrderOrgId != null) {
        final workOrders = await client
            .from('work_orders')
            .select('id, title, status, priority, due_date')
            .eq('org_id', workOrderOrgId)
            .order('updated_at', ascending: false)
            .limit(5);
        final orderList = workOrders as List<dynamic>;
        if (orderList.isNotEmpty) {
          final lines = orderList.map((row) {
            final data = row as Map;
            final title = data['title']?.toString() ?? 'Work Order';
            final status = data['status']?.toString() ?? 'unknown';
            final priority = data['priority']?.toString() ?? 'normal';
            final dueRaw = data['due_date']?.toString();
            final dueDate = dueRaw == null ? null : DateTime.tryParse(dueRaw);
            final dueLabel = dueDate == null ? '' : ' (due ${formatter.format(dueDate)})';
            return '- $title [$status/$priority]$dueLabel';
          }).join('\n');
          contextParts.add('Recent Work Orders:\n$lines');
        }
      }
    } catch (e) {
      // Silently skip work orders context
    }

    // Get recent forms (org-scoped)
    try {
      final formsProfile = await ref.read(userProfileProvider.future);
      final formsOrgId = formsProfile.orgId;
      if (formsOrgId != null) {
        final formsRes = await client
            .from('forms')
            .select('id, title, category')
            .eq('org_id', formsOrgId)
            .eq('is_published', true)
            .order('updated_at', ascending: false)
            .limit(5);
        if (formsRes.isNotEmpty) {
          final formLines = (formsRes as List).map((f) {
            final title = f['title']?.toString() ?? 'Untitled';
            final category = f['category']?.toString() ?? '';
            return category.isNotEmpty ? '- $title [$category]' : '- $title';
          }).join('\n');
          contextParts.add('Available Forms:\n$formLines');
        }
      }
    } catch (e) {
      // Silently skip forms context
    }

    // Get recent documents (org-scoped)
    try {
      final docsProfile = await ref.read(userProfileProvider.future);
      final docsOrgId = docsProfile.orgId;
      if (docsOrgId != null) {
        final docsRes = await client
            .from('documents')
            .select('id, title, category, is_template')
            .eq('org_id', docsOrgId)
            .eq('is_published', true)
            .order('updated_at', ascending: false)
            .limit(5);
        if (docsRes.isNotEmpty) {
          final docLines = (docsRes as List).map((d) {
            final title = d['title']?.toString() ?? 'Untitled';
            final category = d['category']?.toString() ?? '';
            final isTemplate = d['is_template'] == true;
            final suffix = isTemplate ? ' [Template]' : '';
            return category.isNotEmpty
                ? '- $title [$category]$suffix'
                : '- $title$suffix';
          }).join('\n');
          contextParts.add('Available Documents:\n$docLines');
        }
      }
    } catch (e) {
      // Silently skip documents context
    }

    // Get assets (org-scoped)
    try {
      final assetsProfile = await ref.read(userProfileProvider.future);
      final assetsOrgId = assetsProfile.orgId;
      if (assetsOrgId != null) {
        final assetsRes = await client
            .from('equipment')
            .select('id, name, category, status')
            .eq('org_id', assetsOrgId)
            .eq('is_active', true)
            .order('updated_at', ascending: false)
            .limit(5);
        if (assetsRes.isNotEmpty) {
          final assetLines = (assetsRes as List).map((a) {
            final name = a['name']?.toString() ?? 'Unnamed';
            final category = a['category']?.toString() ?? '';
            final status = a['status']?.toString() ?? '';
            return category.isNotEmpty
                ? '- $name [$category]${status.isNotEmpty ? " ($status)" : ""}'
                : '- $name${status.isNotEmpty ? " ($status)" : ""}';
          }).join('\n');
          contextParts.add('Organization Assets:\n$assetLines');
        }
      }
    } catch (e) {
      // Silently skip assets context
    }

    // Get recent announcements/news posts (org-scoped)
    try {
      final newsProfile = await ref.read(userProfileProvider.future);
      final newsOrgId = newsProfile.orgId;
      if (newsOrgId != null) {
        final newsRes = await client
            .from('news_posts')
            .select('id, title, body, scope, published_at')
            .eq('org_id', newsOrgId)
            .eq('is_published', true)
            .order('published_at', ascending: false)
            .limit(3);
        if (newsRes.isNotEmpty) {
          final newsLines = (newsRes as List).map((n) {
            final title = n['title']?.toString() ?? 'Untitled';
            final scope = n['scope']?.toString() ?? '';
            final publishedAt = DateTime.tryParse(n['published_at']?.toString() ?? '');
            final dateStr = publishedAt != null
                ? DateFormat('MMM d').format(publishedAt)
                : '';
            return '- $title${scope.isNotEmpty ? " [$scope]" : ""}${dateStr.isNotEmpty ? " ($dateStr)" : ""}';
          }).join('\n');
          contextParts.add('Recent Announcements:\n$newsLines');
        }
      }
    } catch (e) {
      // Silently skip announcements context
    }

    // Get recent notifications (org-scoped, for current user)
    try {
      final notifProfile = await ref.read(userProfileProvider.future);
      final notifOrgId = notifProfile.orgId;
      if (notifOrgId != null) {
        final notifRes = await client
            .from('notifications')
            .select('id, title, body, type, is_read, created_at')
            .eq('org_id', notifOrgId)
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(5);
        if (notifRes.isNotEmpty) {
          final unreadCount = (notifRes as List).where((n) => n['is_read'] != true).length;
          if (unreadCount > 0) {
            contextParts.add('Unread Notifications: $unreadCount');
          }
        }
      }
    } catch (e) {
      // Silently skip notifications context
    }

    _cachedContext = contextParts.join('\n');
    _lastFetch = DateTime.now();
    return _cachedContext!;
  }

  void invalidate() {
    _lastFetch = null;
    _cachedContext = null;
  }

  /// Search organization SOPs relevant to a question
  Future<String> searchOrgSops(String question, String orgId) async {
    final client = Supabase.instance.client;

    try {
      // Extract keywords from question (words > 2 chars)
      final keywords = question
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2)
          .take(5)
          .toList();
      if (keywords.isEmpty) return '';

      // Query published SOPs with metadata containing latest_body
      final response = await client
          .from('sop_documents')
          .select('title, summary, category, tags, metadata')
          .eq('org_id', orgId)
          .eq('status', 'published')
          .order('updated_at', ascending: false)
          .limit(10);

      if (response.isEmpty) return '';

      // Score and filter results based on keyword relevance
      final scored = <Map<String, dynamic>>[];
      for (final doc in response as List) {
        final title = (doc['title'] ?? '').toString().toLowerCase();
        final summary = (doc['summary'] ?? '').toString().toLowerCase();
        final category = (doc['category'] ?? '').toString().toLowerCase();
        final tags = (doc['tags'] as List?)
                ?.map((t) => t.toString().toLowerCase())
                .toList() ??
            [];
        final body = ((doc['metadata'] as Map?)?['latest_body'] ?? '')
            .toString()
            .toLowerCase();

        int score = 0;
        for (final kw in keywords) {
          if (title.contains(kw)) score += 10;
          if (summary.contains(kw)) score += 5;
          if (category.contains(kw)) score += 3;
          if (tags.any((t) => t.contains(kw))) score += 3;
          if (body.contains(kw)) score += 2;
        }

        if (score > 0) {
          scored.add({...doc, '_score': score});
        }
      }

      if (scored.isEmpty) return '';

      // Sort by score and take top 3
      scored.sort((a, b) => (b['_score'] as int).compareTo(a['_score'] as int));
      final top = scored.take(3);

      final docs = top.map((doc) {
        final title = doc['title'] ?? 'Untitled';
        final category = doc['category'] ?? '';
        final body =
            (doc['metadata'] as Map?)?['latest_body'] ?? doc['summary'] ?? '';
        // Truncate body if too long
        final truncatedBody =
            body.length > 1500 ? '${body.substring(0, 1500)}...' : body;
        return '### $title${category.isNotEmpty ? " [$category]" : ""}\n$truncatedBody';
      }).join('\n\n');

      return docs;
    } catch (e) {
      return '';
    }
  }
}

// =============================================================================
// CHAT STATE
// =============================================================================

/// State for the AI chat feature
class AiChatState {
  const AiChatState({
    this.currentConversation,
    this.recentConversations = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.isInitialized = false,
  });

  final ChatConversation? currentConversation;
  final List<ChatConversation> recentConversations;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final bool isInitialized;

  List<ChatMessage> get messages => currentConversation?.messages ?? [];
  bool get hasConversation => currentConversation != null;

  AiChatState copyWith({
    ChatConversation? currentConversation,
    List<ChatConversation>? recentConversations,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool? isInitialized,
    bool clearError = false,
    bool clearConversation = false,
  }) {
    return AiChatState(
      currentConversation: clearConversation ? null : (currentConversation ?? this.currentConversation),
      recentConversations: recentConversations ?? this.recentConversations,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Notifier for managing AI chat state
class AiChatNotifier extends legacy.StateNotifier<AiChatState> {
  AiChatNotifier(this._ref) : super(const AiChatState()) {
    _initialize();
  }

  final Ref _ref;
  final _contextCache = _AiContextCache();

  AiChatRepository get _repository => _ref.read(aiChatRepositoryProvider);

  /// Initialize the chat state - load recent conversation
  Future<void> _initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true);

    try {
      // Load recent conversations
      final recent = await _repository.getRecentConversations(limit: 10);

      // Load most recent conversation with messages
      final mostRecent = await _repository.getMostRecentConversation();

      if (mounted) {
        state = state.copyWith(
          currentConversation: mostRecent,
          recentConversations: recent,
          isLoading: false,
          isInitialized: true,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load conversations',
          isInitialized: true,
        );
      }
    }
  }

  /// Send a message and get AI response
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || state.isSending) return;

    state = state.copyWith(isSending: true, clearError: true);

    try {
      // Create conversation if needed
      ChatConversation conversation = state.currentConversation ??
          await _createNewConversation();

      // Add user message to database
      final userMessage = await _repository.addMessage(
        conversationId: conversation.id,
        role: ChatRole.user,
        content: content.trim(),
      );

      if (userMessage == null) {
        throw Exception('Failed to save message');
      }

      // Update local state with user message
      conversation = conversation.addMessage(userMessage);
      state = state.copyWith(currentConversation: conversation);

      // Get AI response
      final aiResponse = await _getAiResponse(content.trim(), conversation);

      // Add assistant message to database
      final assistantMessage = await _repository.addMessage(
        conversationId: conversation.id,
        role: ChatRole.assistant,
        content: aiResponse,
      );

      if (assistantMessage == null) {
        throw Exception('Failed to save AI response');
      }

      // Update local state with assistant message
      conversation = conversation.addMessage(assistantMessage);

      if (mounted) {
        state = state.copyWith(
          currentConversation: conversation,
          isSending: false,
        );
      }
    } catch (e) {
      if (mounted) {
        // Add error message locally (don't save to DB)
        final errorMessage = ChatMessage.assistant(
          id: 'error-${DateTime.now().millisecondsSinceEpoch}',
          conversationId: state.currentConversation?.id ?? '',
          content: 'Sorry, I encountered an error. Please try again.',
        );

        final updatedConversation = state.currentConversation?.addMessage(errorMessage);

        state = state.copyWith(
          currentConversation: updatedConversation,
          isSending: false,
          error: e.toString(),
        );
      }
    }
  }

  /// Create a new conversation
  Future<ChatConversation> _createNewConversation() async {
    final conversation = await _repository.createConversation();
    if (conversation == null) {
      throw Exception('Failed to create conversation');
    }
    return conversation;
  }

  /// Get AI response using the existing AI job runner
  Future<String> _getAiResponse(String question, ChatConversation conversation) async {
    final ai = _ref.read(aiJobRunnerProvider);

    // Get cached context (user, projects, tasks, work orders, forms, assets)
    final appContext = await _contextCache.getContext(_ref);

    // Get user's org ID for SOP search
    final profile = await _ref.read(userProfileProvider.future);
    final orgId = profile.orgId;

    // Search org-specific SOPs relevant to the question
    String sopContext = '';
    if (orgId != null) {
      sopContext = await _contextCache.searchOrgSops(question, orgId);
    }

    // Build conversation history from recent messages
    final recentMessages = conversation.messages.length > 6
        ? conversation.messages.sublist(conversation.messages.length - 6)
        : conversation.messages;

    final history = recentMessages
        .map((m) => '${m.role == ChatRole.user ? 'User' : 'Assistant'}: ${m.content}')
        .join('\n');

    final prompt = '''You are a helpful AI assistant for a field service management app called Form Bridge.
You help users manage projects, tasks, work orders, forms, and assets.

IMPORTANT GUIDELINES:
- Provide detailed, helpful responses based on the user's context
- When organization procedures (SOPs) are provided below, reference them in your answers
- If asked about procedures not in the provided SOPs, say you don't have that specific procedure documented
- Use markdown formatting for lists and emphasis
- Be proactive in offering related suggestions

${sopContext.isNotEmpty ? 'ORGANIZATION PROCEDURES (SOPs):\n$sopContext\n\n' : ''}
${appContext.isNotEmpty ? 'USER CONTEXT:\n$appContext\n' : ''}
${history.isNotEmpty ? 'CONVERSATION HISTORY:\n$history\n' : ''}
USER QUESTION: $question

Provide a helpful, detailed response:''';

    final response = await ai.runJob(
      type: 'assistant',
      inputText: prompt,
    );

    return response.trim();
  }

  /// Start a new conversation
  Future<void> startNewConversation() async {
    state = state.copyWith(clearConversation: true, clearError: true);
  }

  /// Load a specific conversation
  Future<void> loadConversation(String conversationId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final conversation = await _repository.getConversation(conversationId);
      if (mounted) {
        state = state.copyWith(
          currentConversation: conversation,
          isLoading: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load conversation',
        );
      }
    }
  }

  /// Archive the current conversation
  Future<void> archiveCurrentConversation() async {
    if (state.currentConversation == null) return;

    await _repository.archiveConversation(state.currentConversation!.id);

    // Refresh recent conversations
    final recent = await _repository.getRecentConversations(limit: 10);

    if (mounted) {
      state = state.copyWith(
        clearConversation: true,
        recentConversations: recent,
      );
    }
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Retry sending the last message after an error
  Future<void> retryLastMessage() async {
    if (state.currentConversation == null) return;

    final messages = state.currentConversation!.messages;
    if (messages.isEmpty) return;

    // Find the last user message
    final lastUserMessage = messages.reversed
        .firstWhere((m) => m.role == ChatRole.user, orElse: () => messages.last);

    if (lastUserMessage.role == ChatRole.user) {
      // Remove error message if present
      final filteredMessages = messages.where((m) => !m.id.startsWith('error-')).toList();

      state = state.copyWith(
        currentConversation: state.currentConversation!.copyWith(messages: filteredMessages),
        clearError: true,
      );

      // Resend
      await sendMessage(lastUserMessage.content);
    }
  }

  /// Delete all conversation history
  Future<void> deleteAllHistory() async {
    state = state.copyWith(isLoading: true);

    try {
      await _repository.deleteAllConversations();
      if (mounted) {
        state = state.copyWith(
          clearConversation: true,
          recentConversations: const [],
          isLoading: false,
          clearError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to delete history',
        );
      }
    }
  }
}

/// Provider for AI chat state
final aiChatProvider = legacy.StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(ref);
});

/// Provider for current conversation messages
final currentMessagesProvider = Provider<List<ChatMessage>>((ref) {
  return ref.watch(aiChatProvider).messages;
});

/// Provider for whether chat is sending
final isChatSendingProvider = Provider<bool>((ref) {
  return ref.watch(aiChatProvider).isSending;
});
