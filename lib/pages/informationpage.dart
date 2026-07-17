import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:wikipedia/wikipedia.dart';

class InformationPage extends StatefulWidget {
  final String disease;
  const InformationPage({super.key, required this.disease});

  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  static const Color primaryTeal = Color(0xFF00BFA5);
  static const Color darkTeal    = Color(0xFF00897B);
  static const Color lightTeal   = Color(0xFFE0F2F1);
  static const Color textDark    = Color(0xFF1A1A2E);

  bool _isLoading = true;
  bool _hasError = false;
  dynamic _resultDesc;

  Future<void> _getData() async {
    try {
      final wikipedia = Wikipedia();
      final result = await wikipedia.searchQuery(
          searchQuery: widget.disease, limit: 1);

      // FIX: guard against null result or empty search list
      if (result == null ||
          result.query == null ||
          result.query!.search == null ||
          result.query!.search!.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      // Try each result until we find one with a valid pageId
      dynamic desc;
      for (final item in result.query!.search!) {
        final pageId = item.pageid;
        if (pageId != null) {
          desc = await wikipedia.searchSummaryWithPageId(pageId: pageId);
          if (desc != null) break;
        }
      }

      setState(() {
        _resultDesc = desc;
        _isLoading = false;
        _hasError = desc == null; // show error if no page found
      });
    } catch (e) {
      debugPrint('Wikipedia fetch error: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getData();
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading state ─────────────────────────────────────────
    if (_isLoading) {
      return Scaffold(
        backgroundColor: lightTeal,
        appBar: AppBar(
          backgroundColor: primaryTeal,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
          title:
              const Text('Loading...', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: primaryTeal)),
      );
    }

    // ── Error / no data state ─────────────────────────────────
    if (_hasError || _resultDesc == null) {
      return Scaffold(
        backgroundColor: lightTeal,
        appBar: AppBar(
          backgroundColor: primaryTeal,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
          title: Text(widget.disease,
              style: const TextStyle(color: Colors.white))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.grey[300], size: 60),
              const SizedBox(height: 16),
              Text('Could not load information',
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Check your internet connection',
                  style:
                      TextStyle(color: Colors.grey[400], fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // ── Main content ──────────────────────────────────────────
    return Scaffold(
      backgroundColor: lightTeal,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: primaryTeal,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                  (_resultDesc.title as String?) ?? widget.disease,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryTeal, darkTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                    child: Icon(Icons.local_hospital_rounded,
                        color: Colors.white30, size: 100)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description chip
                  if (_resultDesc.description != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: lightTeal,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: primaryTeal.withOpacity(0.3)),
                      ),
                      child: Text(
                          (_resultDesc.description as String?) ?? '',
                          style: const TextStyle(
                              color: darkTeal,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  const SizedBox(height: 20),

                  // Article content
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.article_outlined,
                                color: primaryTeal, size: 20),
                            const SizedBox(width: 8),
                            const Text('Overview',
                                style: TextStyle(
                                    color: textDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: lightTeal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Wikipedia',
                                  style: TextStyle(
                                      color: darkTeal,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        ExpandableText(
                          (_resultDesc.extract as String?) ??
                              'No information available.',
                          textAlign: TextAlign.justify,
                          animation: true,
                          expandText: 'Read more',
                          collapseText: 'Show less',
                          maxLines: 8,
                          linkColor: primaryTeal,
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFFF9A825), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              'Information sourced from Wikipedia. '
                              'Always consult a qualified doctor for medical advice.',
                              style: TextStyle(
                                  color: Color(0xFF6D4C00),
                                  fontSize: 12,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}