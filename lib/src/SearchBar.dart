import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'QuerySetLoader.dart';
import 'SearchBarAttrs.dart';
import 'SearchBarBuilder.dart';
import 'StateHolder.dart';

class SearchBar extends StatefulWidget implements PreferredSizeWidget {
  SearchBar({
    @required this.defaultAppBar,
    this.onQueryChanged,
    this.onQuerySubmitted,
    this.loader,
    this.searchHint = 'Tap to search...',
    this.iconified = true,
    bool autofocus,
    ValueChanged<bool> onActivatedChanged,
    SearchBarAttrs attrs,
  })  : this.autofocus = autofocus ?? iconified,
        this.attrs = _initAttrs(iconified, attrs),
        this.activatedChangedCallback =
            onActivatedChanged ?? _blankActivatedCallback;

  static SearchBarAttrs _initAttrs(bool iconified, SearchBarAttrs attrs) {
    final defaultAttrs =
        iconified ? _defaultIconifiedAttrs : _defaultMergedAttrs;
    return attrs != null ? defaultAttrs.merge(attrs) : defaultAttrs;
  }

  static const _defaultIconifiedAttrs = SearchBarAttrs(
    textBoxBackgroundColor: Colors.transparent,
    textBoxOutlineColor: Colors.transparent,
  );

  static const _defaultMergedAttrs = SearchBarAttrs(
    textBoxBackgroundColor: Colors.black12,
    textBoxOutlineColor: Colors.black26,
  );

  bool get _shouldTakeWholeSpace =>
      (_stateHolder.value?.activated ?? false) && loader != null;

  Size get _tryGetScreenSize {
    final context = _stateHolder.value?.context;
    return (context != null) ? MediaQuery.of(context).size : null;
  }

  Size get _tryGetAvailableSpace {
    final screenSize = _tryGetScreenSize;
    return (screenSize != null)
        ? Size(screenSize.width, screenSize.height - attrs.loaderBottomMargin)
        : null;
  }

  final _stateHolder = StateHolder<SearchBarState>();

  final ValueChanged<String> onQueryChanged;

  final ValueChanged<String> onQuerySubmitted;

  final QuerySetLoader loader;

  final SearchBarAttrs attrs;

  final AppBar defaultAppBar;

  final String searchHint;

  final bool iconified;

  final bool autofocus;

  final ValueChanged<bool> activatedChangedCallback;

  static final ValueChanged<bool> _blankActivatedCallback = (_) {};

  @override
  Size get preferredSize {
    return _shouldTakeWholeSpace
        ? _tryGetAvailableSpace ?? attrs.searchBarSize
        : attrs.searchBarSize;
  }

  @override
  State createState() => _stateHolder.applyState(SearchBarState());
}

class SearchBarState extends State<SearchBar> {
  final FocusNode searchFocusNode = FocusNode();

  final TextEditingController queryInputController = TextEditingController();

  QuerySetLoader get _safeLoader => widget.loader ?? QuerySetLoader.blank;

  bool activated = false;

  bool focused = false;

  bool queryNotEmpty = false;

  bool isClearingQuery = false;

  bool expanded;

  String loaderQuery;

  Orientation currentOrientation;

  @override
  void initState() {
    super.initState();
    expanded = !widget.iconified;
    queryInputController.addListener(_onQueryControllerChange);
    searchFocusNode.addListener(_onSearchFocusChange);
  }

  void _onQueryControllerChange() {
    queryNotEmpty = queryInputController.text.isNotEmpty;
    if (isClearingQuery) {
      isClearingQuery = false;
      onTextChange('');
    }
  }

  void onTextChange(String text) {
    setState(() {
      if (_safeLoader.loadOnEachChange) loaderQuery = text;
    });
    if (widget.onQueryChanged != null) widget.onQueryChanged(text);
  }

  void onTextSubmit(String text) {
    setState(() {
      if (!_safeLoader.loadOnEachChange) loaderQuery = text;
    });
    if (widget.onQuerySubmitted != null) widget.onQuerySubmitted(text);
  }

  void _onSearchFocusChange() {
    setState(() {
      focused = searchFocusNode.hasFocus;
      if (focused && !activated) {
        activated = true;
        widget.activatedChangedCallback(true);
      }
    });
    _redrawScaffold();
  }

  void onCancelSearch() {
    setState(() {
      if (activated) {
        activated = false;
        widget.activatedChangedCallback(false);
      }
      if (widget.iconified) expanded = false;
    });
    queryInputController.clear();
    searchFocusNode.unfocus();
    _redrawScaffold();
  }

  void _redrawScaffold() {
    Scaffold.of(context).setState(() {});
  }

  void onPrefixSearchTap() {
    FocusScope.of(context).requestFocus(searchFocusNode);
    _highlightQueryText();
  }

  void _highlightQueryText() {
    queryInputController.selection = TextSelection(
      baseOffset: queryInputController.value.text.length,
      extentOffset: 0,
    );
  }

  void onClearQuery() {
    if (queryNotEmpty) {
      _clearQueryField();
    } else {
      searchFocusNode.unfocus();
    }
  }

  void _clearQueryField() {
    isClearingQuery = true;
    queryInputController.clear();
  }

  void onSearchAction() {
    setState(() {
      expanded = true;
    });
  }

  @override
  void dispose() {
    searchFocusNode.dispose();
    queryInputController.dispose();
    super.dispose();
  }

  Future<bool> onWillPop() {
    bool shouldPop;
    if (activated) {
      onCancelSearch();
      shouldPop = false;
    } else {
      shouldPop = true;
    }
    return Future.value(shouldPop);
  }

  void _handleOrientationIfChanged(BuildContext context) async {
    final orientation = MediaQuery.of(context).orientation;
    if (currentOrientation != orientation) {
      currentOrientation = orientation;
      _redrawScaffold();
    }
  }

  @override
  Widget build(BuildContext context) {
    _handleOrientationIfChanged(context);
    return SearchBarBuilder(this);
  }
}
