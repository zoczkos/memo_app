import 'package:flutter/material.dart';

enum CardMenuAction { add, edit }

/// Compact AppBar overflow menu for adding or editing the current card.
class CardActionsMenu extends StatelessWidget {
  final bool canEdit;
  final Color? iconColor;
  final ValueChanged<CardMenuAction> onSelected;

  const CardActionsMenu({
    super.key,
    required this.canEdit,
    required this.onSelected,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CardMenuAction>(
      icon: Icon(Icons.more_vert, color: iconColor),
      tooltip: 'Card options',
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: CardMenuAction.add,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add),
            title: Text('Add card'),
          ),
        ),
        PopupMenuItem(
          value: CardMenuAction.edit,
          enabled: canEdit,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit card'),
          ),
        ),
      ],
    );
  }
}
