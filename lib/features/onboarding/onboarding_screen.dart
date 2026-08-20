import 'package:flutter/material.dart';

/// A swipeable onboarding tutorial explaining how to play Impostor.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onComplete});

  /// Called when the user finishes or skips the tutorial.
  final VoidCallback? onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = <_TutorialPage>[
    _TutorialPage(
      icon: Icons.psychology_alt,
      title: 'Welcome to Impostor',
      body: 'A social deduction party game where players try to '
          'find the impostor among them.\n\n'
          'Pass the phone around — each player sees their role privately.',
      color: Colors.indigo,
    ),
    _TutorialPage(
      icon: Icons.groups_rounded,
      title: 'Setup',
      body: 'Add at least 3 players.\n\n'
          'Choose which word themes to use and how many impostors '
          'are in the game.\n\n'
          'You can also pick the language for the secret word.',
      color: Colors.teal,
    ),
    _TutorialPage(
      icon: Icons.visibility_off_rounded,
      title: 'Role Reveal',
      body: 'Each player takes the phone privately and taps '
          '"Reveal My Role".\n\n'
          'Innocent players see the secret word.\n'
          'Impostors see that they are the impostor — '
          'they do NOT know the word.',
      color: Colors.deepPurple,
    ),
    _TutorialPage(
      icon: Icons.chat_bubble_rounded,
      title: 'Discussion',
      body: 'Players discuss to figure out who the impostor is.\n\n'
          'Ask questions about the word without giving it away — '
          'the impostor is trying to blend in!',
      color: Colors.orange,
    ),
    _TutorialPage(
      icon: Icons.how_to_vote_rounded,
      title: 'Voting & Winning',
      body: 'After discussion, vote to eliminate a suspect.\n\n'
          'Innocents win when all impostors are found.\n'
          'Impostors win if they survive until there are '
          'equal or fewer innocents than impostors.',
      color: Colors.red,
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    widget.onComplete?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(context, page);
                },
              ),
            ),

            // Dots + navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicator dots
                  Row(
                    children: List.generate(_pages.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isActive
                              ? colorScheme.primary
                              : colorScheme.onSurface.withAlpha(60),
                        ),
                      );
                    }),
                  ),

                  // Next / Get Started button
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(isLast ? 'Get Started' : 'Next'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, _TutorialPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.color.withAlpha(30),
              boxShadow: [
                BoxShadow(
                  color: page.color.withAlpha(25),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(page.icon, size: 72, color: page.color),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            page.body,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Data class for a single tutorial page.
class _TutorialPage {
  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
}
