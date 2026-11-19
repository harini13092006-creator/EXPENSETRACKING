import 'package:flutter/material.dart';

class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    required this.onSelected,
    this.busy = false,
    this.loadingProvider,
    this.labelPrefix = 'Continue with',
    super.key,
  });

  final ValueChanged<String> onSelected;
  final bool busy;
  final String? loadingProvider;
  final String labelPrefix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or continue with'),
          ),
          Expanded(child: Divider()),
        ],
      ),
      const SizedBox(height: 14),
      for (final provider in _providers)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            onPressed: busy ? null : () => onSelected(provider.id),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: loadingProvider == provider.id
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ProviderMark(provider: provider),
                      const SizedBox(width: 12),
                      Text(
                        '$labelPrefix ${provider.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
    ],
  );

  static const _providers = <_ProviderInfo>[
    _ProviderInfo('google', 'Google', 'G', Color(0xFF4285F4)),
    _ProviderInfo('apple', 'Apple', '', Color(0xFF111111)),
    _ProviderInfo('facebook', 'Facebook', 'f', Color(0xFF1877F2)),
    _ProviderInfo('microsoft', 'Microsoft', '▦', Color(0xFF5E5E5E)),
  ];
}

class _ProviderInfo {
  const _ProviderInfo(this.id, this.name, this.mark, this.color);
  final String id;
  final String name;
  final String mark;
  final Color color;
}

class _ProviderMark extends StatelessWidget {
  const _ProviderMark({required this.provider});
  final _ProviderInfo provider;

  @override
  Widget build(BuildContext context) {
    if (provider.id == 'apple') {
      return const SizedBox(
        width: 20,
        child: Icon(Icons.apple, size: 19),
      );
    }
    if (provider.id == 'microsoft') {
      return const SizedBox(width: 20, height: 20, child: _MicrosoftMark());
    }
    return SizedBox(
      width: 20,
      child: Text(
        provider.mark,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: provider.color,
          fontWeight: FontWeight.w800,
          fontSize: 19,
        ),
      ),
    );
  }
}

class _MicrosoftMark extends StatelessWidget {
  const _MicrosoftMark();
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Expanded(
        child: Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFFF25022))),
            SizedBox(width: 2),
            Expanded(child: ColoredBox(color: Color(0xFF7FBA00))),
          ],
        ),
      ),
      SizedBox(height: 2),
      Expanded(
        child: Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFF00A4EF))),
            SizedBox(width: 2),
            Expanded(child: ColoredBox(color: Color(0xFFFFB900))),
          ],
        ),
      ),
    ],
  );
}
