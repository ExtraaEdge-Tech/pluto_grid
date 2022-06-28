import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

typedef DragUpdatedCallback = Function(Offset offset);

class PlutoDefaultCell extends PlutoStatefulWidget {
  final PlutoCell cell;

  final PlutoColumn column;

  final int rowIdx;

  final PlutoRow row;

  @override
  final PlutoGridStateManager stateManager;

  const PlutoDefaultCell({
    required this.cell,
    required this.column,
    required this.rowIdx,
    required this.row,
    required this.stateManager,
    Key? key,
  }) : super(key: key);

  @override
  State<PlutoDefaultCell> createState() => _PlutoDefaultCellState();
}

class _PlutoDefaultCellState extends PlutoStateWithChange<PlutoDefaultCell> {
  bool _hasFocus = false;

  bool _canRowDrag = false;

  bool _isCurrentCell = false;

  String _text = '';

  @override
  void initState() {
    super.initState();

    updateState();
  }

  @override
  void updateState() {
    _hasFocus = update<bool>(
      _hasFocus,
      widget.stateManager.hasFocus,
    );

    _canRowDrag = update<bool>(
      _canRowDrag,
      widget.column.enableRowDrag && widget.stateManager.canRowDrag,
    );

    _isCurrentCell = update<bool>(
      _isCurrentCell,
      widget.stateManager.isCurrentCell(widget.cell),
    );

    _text = update<String>(
      _text,
      widget.column.formattedValueForDisplay(widget.cell.value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cellWidget = _BuildDefaultCellWidget(
      stateManager: widget.stateManager,
      rowIdx: widget.rowIdx,
      row: widget.row,
      column: widget.column,
      cell: widget.cell,
    );

    return Row(
      children: [
        if (_canRowDrag)
          _RowDragIconWidget(
            column: widget.column,
            row: widget.row,
            rowIdx: widget.rowIdx,
            stateManager: widget.stateManager,
            feedbackWidget: cellWidget,
            dragIcon: Icon(
              Icons.drag_indicator,
              size: widget.stateManager.configuration!.iconSize,
              color: widget.stateManager.configuration!.iconColor,
            ),
          ),
        if (widget.column.enableRowChecked)
          _CheckboxSelectionWidget(
            column: widget.column,
            row: widget.row,
            rowIdx: widget.rowIdx,
            stateManager: widget.stateManager,
          ),
        Expanded(
          child: cellWidget,
        ),
      ],
    );
  }
}

class _RowDragIconWidget extends StatelessWidget {
  final PlutoColumn column;

  final PlutoRow row;

  final int rowIdx;

  final PlutoGridStateManager stateManager;

  final Widget dragIcon;

  final Widget feedbackWidget;

  const _RowDragIconWidget({
    required this.column,
    required this.row,
    required this.rowIdx,
    required this.stateManager,
    required this.dragIcon,
    required this.feedbackWidget,
    Key? key,
  }) : super(key: key);

  List<PlutoRow> get _draggingRows {
    if (stateManager.currentSelectingRows.isEmpty) {
      return [row];
    }

    if (stateManager.isSelectedRow(row.key)) {
      return stateManager.currentSelectingRows;
    }

    // In case there are selected rows,
    // if the dragging row is not included in it,
    // the selection of rows is invalidated.
    stateManager.clearCurrentSelecting(notify: false);

    return [row];
  }

  void _handleOnPointerDown(PointerDownEvent event) {
    stateManager.setIsDraggingRow(true, notify: false);

    stateManager.setDragRows(_draggingRows);
  }

  void _handleOnPointerMove(PointerMoveEvent event) {
    // Do not drag while rows are selected.
    if (stateManager.isSelecting) {
      stateManager.setIsDraggingRow(false);

      return;
    }

    stateManager.eventManager!.addEvent(PlutoGridScrollUpdateEvent(
      offset: event.position,
    ));

    int? targetRowIdx = stateManager.getRowIdxByOffset(
      event.position.dy,
    );

    stateManager.setDragTargetRowIdx(targetRowIdx);
  }

  void _handleOnPointerUp(PointerUpEvent event) {
    stateManager.setIsDraggingRow(false);

    PlutoGridScrollUpdateEvent.stopScroll(
      stateManager,
      PlutoGridScrollUpdateDirection.all,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleOnPointerDown,
      onPointerMove: _handleOnPointerMove,
      onPointerUp: _handleOnPointerUp,
      child: Draggable<PlutoRow>(
        data: row,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: FractionalTranslation(
          translation: const Offset(-0.08, -0.5),
          child: Material(
            child: PlutoShadowContainer(
              width: column.width,
              height: stateManager.rowHeight,
              backgroundColor: stateManager.configuration!.gridBackgroundColor,
              borderColor: stateManager.configuration!.activatedBorderColor,
              child: Row(
                children: [
                  dragIcon,
                  Expanded(
                    child: feedbackWidget,
                  ),
                ],
              ),
            ),
          ),
        ),
        child: dragIcon,
      ),
    );
  }
}

class _CheckboxSelectionWidget extends PlutoStatefulWidget {
  @override
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  final PlutoRow row;

  final int rowIdx;

  const _CheckboxSelectionWidget({
    required this.stateManager,
    required this.column,
    required this.row,
    required this.rowIdx,
  });

  @override
  _CheckboxSelectionWidgetState createState() =>
      _CheckboxSelectionWidgetState();
}

class _CheckboxSelectionWidgetState
    extends PlutoStateWithChange<_CheckboxSelectionWidget> {
  bool? _checked;

  @override
  void initState() {
    super.initState();

    updateState();
  }

  @override
  void updateState() {
    _checked = update<bool?>(
      _checked,
      widget.row.checked == true,
    );
  }

  void _handleOnChanged(bool? changed) {
    if (changed == _checked) {
      return;
    }

    widget.stateManager.setRowChecked(widget.row, changed == true);

    if (widget.stateManager.onRowChecked != null) {
      widget.stateManager.onRowChecked!(
        PlutoGridOnRowCheckedOneEvent(
          row: widget.row,
          rowIdx: widget.rowIdx,
          isChecked: changed,
        ),
      );
    }

    setState(() {
      _checked = changed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlutoScaledCheckbox(
      value: _checked,
      handleOnChanged: _handleOnChanged,
      scale: 0.86,
      unselectedColor: widget.stateManager.configuration!.iconColor,
      activeColor: widget.stateManager.configuration!.activatedBorderColor,
      checkColor: widget.stateManager.configuration!.activatedColor,
    );
  }
}

class _BuildDefaultCellWidget extends StatelessWidget {
  final PlutoGridStateManager stateManager;

  final int rowIdx;

  final PlutoRow row;

  final PlutoColumn column;

  final PlutoCell cell;

  const _BuildDefaultCellWidget({
    required this.stateManager,
    required this.rowIdx,
    required this.row,
    required this.column,
    required this.cell,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (column.hasRenderer) {
      return column.renderer!(PlutoColumnRendererContext(
        column: column,
        rowIdx: rowIdx,
        row: row,
        cell: cell,
        stateManager: stateManager,
      ));
    }

    return Text(
      column.formattedValueForDisplay(cell.value),
      style: stateManager.configuration!.cellTextStyle.copyWith(
        decoration: TextDecoration.none,
        fontWeight: FontWeight.normal,
      ),
      overflow: TextOverflow.ellipsis,
      textAlign: column.textAlign.value,
    );
  }
}
