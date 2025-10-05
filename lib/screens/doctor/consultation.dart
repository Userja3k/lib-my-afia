import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat.dart';
import 'package:intl/intl.dart';

class ConsultationPage extends StatelessWidget {
  final bool isLoading;
  final String errorMessage;
  final List<Map<String, dynamic>> contacts;
  final bool showUnreadOnly;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String) onTapContact;
  final String Function(Timestamp?) formatTime;
  final String Function(Timestamp?) formatLastSeen;

  const ConsultationPage({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.contacts,
    required this.showUnreadOnly,
    required this.onRefresh,
    required this.onTapContact,
    required this.formatTime,
    required this.formatLastSeen,
  });

  // Méthodes responsive
  String _getDeviceType(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return 'mobile';
    } else if (screenWidth < 900) {
      return 'tablet';
    } else if (screenWidth < 1200) {
      return 'small_desktop';
    } else {
      return 'large_desktop';
    }
  }

  double _getResponsiveFontSize(BuildContext context, {double baseSize = 16}) {
    String deviceType = _getDeviceType(context);
    switch (deviceType) {
      case 'mobile':
        return baseSize;
      case 'tablet':
        return baseSize * 1.1;
      case 'small_desktop':
        return baseSize * 1.2;
      case 'large_desktop':
        return baseSize * 1.3;
      default:
        return baseSize;
    }
  }

  EdgeInsets _getResponsivePadding(BuildContext context) {
    String deviceType = _getDeviceType(context);
    switch (deviceType) {
      case 'mobile':
        return const EdgeInsets.all(16.0);
      case 'tablet':
        return const EdgeInsets.all(24.0);
      case 'small_desktop':
        return const EdgeInsets.all(32.0);
      case 'large_desktop':
        return const EdgeInsets.all(40.0);
      default:
        return const EdgeInsets.all(16.0);
    }
  }

  double _getMaxContentWidth(BuildContext context) {
    String deviceType = _getDeviceType(context);
    double screenWidth = MediaQuery.of(context).size.width;
    
    switch (deviceType) {
      case 'mobile':
        return screenWidth;
      case 'tablet':
        return screenWidth * 0.9;
      case 'small_desktop':
        return screenWidth * 0.8;
      case 'large_desktop':
        return 1000;
      default:
        return screenWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String deviceType = _getDeviceType(context);
    final bool isMobile = deviceType == 'mobile';
    final bool isTablet = deviceType == 'tablet';
    final bool isDesktop = deviceType == 'small_desktop' || deviceType == 'large_desktop';
    final ThemeData theme = Theme.of(context);

    List<Map<String, dynamic>> filteredContacts = showUnreadOnly
        ? contacts.where((contact) => contact["unreadCount"] > 0).toList()
        : contacts;

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _getMaxContentWidth(context),
          ),
          padding: _getResponsivePadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded, 
                size: isDesktop ? 90 : isTablet ? 80 : 70, 
                color: theme.colorScheme.error.withOpacity(0.7)
              ),
              SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
              Text(
                errorMessage,
                style: TextStyle(
                  color: theme.colorScheme.error, 
                  fontSize: _getResponsiveFontSize(context, baseSize: 16)
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh_rounded, 
                  color: Colors.white,
                  size: isDesktop ? 24 : isTablet ? 22 : 20,
                ),
                label: Text(
                  'Réessayer',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, baseSize: 14)
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : isTablet ? 28 : 24, 
                    vertical: isDesktop ? 16 : isTablet ? 14 : 12
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          strokeWidth: isDesktop ? 4 : isTablet ? 3.5 : 3,
        ),
      );
    }

    if (filteredContacts.isEmpty) {
      return Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _getMaxContentWidth(context),
          ),
          padding: _getResponsivePadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                showUnreadOnly ? Icons.markunread_mailbox_outlined : Icons.chat_bubble_outline,
                size: isDesktop ? 120 : isTablet ? 110 : 90,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
              ),
              SizedBox(height: isDesktop ? 24 : isTablet ? 20 : 16),
              Text(
                showUnreadOnly ? 'Aucun message non lu' : 'Aucune conversation',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, baseSize: 18),
                  color: theme.textTheme.titleMedium?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
              Text(
                showUnreadOnly ? 'Tous vos messages ont été lus' : 'Commencez une nouvelle consultation',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, baseSize: 14),
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: _getMaxContentWidth(context),
        ),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: theme.colorScheme.primary,
          child: ListView.builder(
            padding: EdgeInsets.only(
              top: isDesktop ? 16.0 : isTablet ? 12.0 : 8.0,
              left: isDesktop ? 16.0 : isTablet ? 12.0 : 10.0,
              right: isDesktop ? 16.0 : isTablet ? 12.0 : 10.0,
            ),
            itemCount: filteredContacts.length,
            itemBuilder: (context, index) {
              final contact = filteredContacts[index];
              final unreadCount = contact["unreadCount"];
              final lastMessage = contact["lastMessage"];
              final lastMessageTime = contact["lastMessageTime"];
              final isOnline = contact["isOnline"];
              final lastSeen = contact["lastSeen"];

              return Card(
                elevation: unreadCount > 0 ? 2 : 1,
                margin: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16 : isTablet ? 12 : 10, 
                  vertical: isDesktop ? 8 : isTablet ? 6 : 5
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
                  side: unreadCount > 0
                      ? BorderSide(color: theme.colorScheme.primary.withOpacity(0.5), width: 1)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () async {
                    await onTapContact(contact["id"]);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          contactId: contact["id"],
                          contactName: contact["id"],
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : 12),
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 16.0 : isTablet ? 14.0 : 12.0),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: unreadCount > 0 
                                  ? theme.colorScheme.primary.withOpacity(0.7) 
                                  : theme.colorScheme.surfaceVariant,
                              radius: isDesktop ? 36 : isTablet ? 32 : 28,
                              child: Text(
                                contact["id"].substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: unreadCount > 0 ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                  fontSize: _getResponsiveFontSize(context, baseSize: 20),
                                ),
                              ),
                            ),
                            if (isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: isDesktop ? 20 : isTablet ? 18 : 16,
                                  height: isDesktop ? 20 : isTablet ? 18 : 16,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.cardColor, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: isDesktop ? 20 : isTablet ? 18 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        if (contact["isConsultation"] == true)
                                          Container(
                                            margin: EdgeInsets.only(right: 8),
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "CONSULTATION",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            "Patient ${contact["id"].substring(0, 6)}...",
                                            style: TextStyle(
                                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                              fontSize: _getResponsiveFontSize(context, baseSize: 17),
                                              color: unreadCount > 0 ? theme.colorScheme.primary : theme.textTheme.titleMedium?.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatTime(lastMessageTime),
                                    style: TextStyle(
                                      fontSize: _getResponsiveFontSize(context, baseSize: 13),
                                      color: unreadCount > 0 ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
                                      fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isDesktop ? 6 : isTablet ? 5 : 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: _getResponsiveFontSize(context, baseSize: 14),
                                        color: unreadCount > 0 
                                            ? theme.textTheme.bodyMedium?.color?.withOpacity(0.8) 
                                            : theme.textTheme.bodySmall?.color,
                                        fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 10 : isTablet ? 9 : 8, 
                                        vertical: isDesktop ? 4 : isTablet ? 3 : 2
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(isDesktop ? 14 : isTablet ? 12 : 12),
                                      ),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: _getResponsiveFontSize(context, baseSize: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (!isOnline && lastSeen != null)
                                Padding(
                                  padding: EdgeInsets.only(top: isDesktop ? 6.0 : isTablet ? 5.0 : 4.0),
                                  child: Text(
                                    formatLastSeen(lastSeen),
                                    style: TextStyle(
                                      fontSize: _getResponsiveFontSize(context, baseSize: 12),
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
