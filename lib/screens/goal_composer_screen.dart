import 'dart:async';

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/laika_api.dart';

class GoalComposerScreen extends StatefulWidget {
  const GoalComposerScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.api,
  });

  final String projectId;
  final String projectName;
  final LaikaApi api;

  @override
  State<GoalComposerScreen> createState() => _GoalComposerScreenState();
}

class _GoalComposerScreenState extends State<GoalComposerScreen> {
  final _ideaController = TextEditingController();
  final _briefController = TextEditingController();
  final _feedbackController = TextEditingController();
  final List<TextEditingController> _answerControllers = [];
  final List<String?> _answers = [];
  AssistantSession? _session;
  Timer? _pollTimer;
  bool _requestInFlight = false;
  bool _atomic = false;
  bool _briefAtomic = false;
  bool _showFeedback = false;
  String? _error;
  String? _briefSessionId;

  bool get _hasIdea => _ideaController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ideaController.dispose();
    _briefController.dispose();
    _feedbackController.dispose();
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _setSession(AssistantSession session) {
    if (!mounted) return;
    if (session.status == 'submitted' || session.status == 'cancelled') {
      _stopPolling();
      setState(() {
        _session = null;
        _error = null;
        _requestInFlight = false;
      });
      return;
    }
    setState(() {
      _session = session;
      _error = null;
      _requestInFlight = false;
    });
    if (session.working) {
      _startPolling(session.id);
    } else {
      _stopPolling();
      if (session.status == 'brief' && _briefSessionId != session.id) {
        final brief = session.brief;
        if (brief != null) {
          _briefController.text = brief.goal;
          _briefAtomic = brief.atomic;
          _briefSessionId = session.id;
        }
      }
      _prepareQuestions(session);
    }
  }

  void _prepareQuestions(AssistantSession session) {
    if (session.status != 'questions' || _answerControllers.length == session.questions.length) {
      return;
    }
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    _answerControllers
      ..clear()
      ..addAll(session.questions.map((_) => TextEditingController()));
    _answers
      ..clear()
      ..addAll(session.questions.map((_) => null));
  }

  void _startPolling(String sessionId) {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || _requestInFlight || _session?.id != sessionId) return;
      _requestInFlight = true;
      try {
        final session = await widget.api.assistant(sessionId);
        if (!mounted) return;
        _setSession(session);
      } on LaikaApiException catch (error) {
        if (mounted) {
          setState(() {
            _error = error.message;
            _requestInFlight = false;
          });
        }
      }
    });
  }

  Future<void> _sendAsWritten() async {
    if (!_hasIdea || _requestInFlight) return;
    setState(() { _requestInFlight = true; _error = null; });
    try {
      await widget.api.submitGoal(widget.projectId, _ideaController.text, atomic: _atomic);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Started. LAIka is on it.')));
    } on LaikaApiException catch (error) {
      if (mounted) setState(() { _requestInFlight = false; _error = error.message; });
    }
  }

  Future<void> _startAssistant() async {
    if (!_hasIdea || _requestInFlight) return;
    setState(() { _requestInFlight = true; _error = null; });
    try {
      _setSession(await widget.api.startAssistant(widget.projectId, _ideaController.text));
    } on LaikaApiException catch (error) {
      if (mounted) setState(() { _requestInFlight = false; _error = error.message; });
    }
  }

  Future<void> _answerQuestions({required bool skip}) async {
    final session = _session;
    if (session == null || _requestInFlight) return;
    setState(() { _requestInFlight = true; _error = null; });
    try {
      final answers = skip
          ? List<String>.filled(session.questions.length, '')
          : List<String>.generate(
              session.questions.length,
              (index) => _answerControllers[index].text,
            );
      _setSession(await widget.api.answerAssistant(session.id, answers));
    } on LaikaApiException catch (error) {
      if (mounted) setState(() { _requestInFlight = false; _error = error.message; });
    }
  }

  Future<void> _reviseBrief() async {
    final session = _session;
    if (session == null || _requestInFlight) return;
    setState(() { _requestInFlight = true; _error = null; });
    try {
      final revised = await widget.api.reviseAssistant(session.id, _feedbackController.text);
      if (!mounted) return;
      _briefSessionId = null;
      _showFeedback = false;
      _feedbackController.clear();
      _setSession(revised);
    } on LaikaApiException catch (error) {
      if (mounted) setState(() { _requestInFlight = false; _error = error.message; });
    }
  }

  Future<void> _submitBrief() async {
    final session = _session;
    if (session == null || _requestInFlight) return;
    setState(() { _requestInFlight = true; _error = null; });
    try {
      await widget.api.submitAssistant(session.id, _briefController.text, atomic: _briefAtomic);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Started. LAIka is on it.')));
    } on LaikaApiException catch (error) {
      if (mounted) setState(() { _requestInFlight = false; _error = error.message; });
    }
  }

  Future<void> _startOver() async {
    final session = _session;
    _stopPolling();
    setState(() { _session = null; _requestInFlight = false; _error = null; });
    if (session != null) {
      try {
        await widget.api.cancelAssistant(session.id);
      } on LaikaApiException {
        // Starting over returns to the editor even if cancellation fails.
      }
    }
  }

  Future<void> _retry() async {
    _stopPolling();
    setState(() { _session = null; _requestInFlight = true; _error = null; });
    try {
      _setSession(await widget.api.startAssistant(widget.projectId, _ideaController.text));
    } on LaikaApiException catch (error) {
      if (mounted) setState(() { _requestInFlight = false; _error = error.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: Text('Give ${widget.projectName} work'),
        actions: [
          if (session != null)
            TextButton(onPressed: _requestInFlight ? null : _startOver, child: const Text('Start over')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: session == null ? _compose() : _assistant(session),
      ),
    );
  }

  Widget _compose() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _ideaController,
        minLines: 4,
        maxLines: 8,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: 'What should LAIka do in ${widget.projectName}?'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Small change (one step)'),
        value: _atomic,
        onChanged: _requestInFlight ? null : (value) => setState(() => _atomic = value ?? false),
      ),
      if (_error != null) _errorText(),
      FilledButton(onPressed: !_hasIdea || _requestInFlight ? null : _sendAsWritten, child: const Text('Send as written')),
      OutlinedButton(onPressed: !_hasIdea || _requestInFlight ? null : _startAssistant, child: const Text('Plan it with me')),
    ],
  );

  Widget _assistant(AssistantSession session) {
    final content = switch (session.status) {
      'queued' || 'thinking' => _working(),
      'questions' => _questions(session),
      'brief' => _brief(session),
      'failed' => _failed(session),
      _ => _compose(),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [content, if (_error != null) _errorText()]);
  }

  Widget _working() => const Row(children: [CircularProgressIndicator(), SizedBox(width: 12), Expanded(child: Text('Reading the project and thinking…'))]);

  Widget _questions(AssistantSession session) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < session.questions.length; index++) ...[
        Text(session.questions[index].question),
        Wrap(spacing: 8, children: [
          for (final option in session.questions[index].options)
            ChoiceChip(
              label: Text(option),
              selected: _answerControllers[index].text == option,
              onSelected: _requestInFlight ? null : (_) => setState(() {
                _answerControllers[index].text = option;
                _answers[index] = option;
              }),
            ),
        ]),
        TextField(
          controller: _answerControllers[index],
          onChanged: (value) => _answers[index] = value,
          decoration: const InputDecoration(labelText: 'Your answer'),
        ),
        const SizedBox(height: 12),
      ],
      FilledButton(onPressed: _requestInFlight ? null : () => _answerQuestions(skip: false), child: const Text('Continue')),
      TextButton(onPressed: _requestInFlight ? null : () => _answerQuestions(skip: true), child: const Text('Skip questions')),
    ],
  );

  Widget _brief(AssistantSession session) {
    final brief = session.brief;
    if (brief == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(brief.title, style: Theme.of(context).textTheme.headlineSmall),
      Text(brief.summary),
      TextField(controller: _briefController, minLines: 5, maxLines: 10),
      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Small change (one step)'), value: _briefAtomic, onChanged: _requestInFlight ? null : (value) => setState(() => _briefAtomic = value ?? false)),
      if (_showFeedback) ...[
        TextField(controller: _feedbackController, decoration: const InputDecoration(labelText: 'What should change?')),
        OutlinedButton(onPressed: _requestInFlight ? null : _reviseBrief, child: const Text('Rewrite brief')),
      ] else
        TextButton(onPressed: _requestInFlight ? null : () => setState(() => _showFeedback = true), child: const Text('Change something')),
      FilledButton(onPressed: _requestInFlight ? null : _submitBrief, child: const Text('Start this goal')),
    ]);
  }

  Widget _failed(AssistantSession session) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(session.error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    FilledButton(onPressed: _requestInFlight ? null : _sendAsWritten, child: const Text('Send my idea as written')),
    OutlinedButton(onPressed: _requestInFlight ? null : _retry, child: const Text('Try again')),
  ]);

  Widget _errorText() => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));
}
