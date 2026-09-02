import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/password_entry.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../../../utils/responsive.dart';
import '../../../../providers/data_provider.dart';

class PasswordCard extends StatelessWidget {
  final PasswordEntry password;
  final VoidCallback? onTap;
  final Function(String, PasswordEntry)? onAction;

  const PasswordCard({
    super.key,
    required this.password,
    this.onTap,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveBreakpoints.responsive<double>(
          context,
          mobile: AppConstants.spacingS,
          tablet: AppConstants.spacingM,
          desktop: AppConstants.spacingL,
        ),
      ),
      elevation: ResponsiveBreakpoints.responsive<double>(
        context,
        mobile: 2,
        tablet: 3,
        desktop: 4,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        child: Padding(
          padding: ResponsiveBreakpoints.responsivePadding(
            context,
            mobile: const EdgeInsets.all(AppConstants.spacingM),
            tablet: const EdgeInsets.all(AppConstants.spacingL),
            desktop: const EdgeInsets.all(20),
          ),
          child: ResponsiveBuilder(
            mobile: _buildMobileLayout(context),
            tablet: _buildTabletLayout(context),
            desktop: _buildDesktopLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Row(
      children: [
        // Icon
        _buildIcon(context, size: 50),
        const SizedBox(width: AppConstants.spacingM),
        
        // Content
        Expanded(child: _buildContent(context, compact: true)),
        
        // Trailing Actions
        _buildTrailingActions(context),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildIcon(context, size: 56),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle(context),
                  const SizedBox(height: 4),
                  _buildCategory(context),
                ],
              ),
            ),
            _buildTrailingActions(context),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        _buildUsername(context),
        const SizedBox(height: AppConstants.spacingS),
        Row(
          children: [
            Expanded(child: _buildUrl(context)),
            _buildDate(context),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildIcon(context, size: 64),
            const SizedBox(width: AppConstants.spacingL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle(context, fontSize: 18),
                  const SizedBox(height: 6),
                  _buildCategory(context, fontSize: 14),
                ],
              ),
            ),
            _buildTrailingActions(context),
          ],
        ),
        const SizedBox(height: AppConstants.spacingL),
        _buildUsername(context, fontSize: 16),
        const SizedBox(height: AppConstants.spacingM),
        Row(
          children: [
            Expanded(child: _buildUrl(context, fontSize: 14)),
            _buildDate(context, fontSize: 14),
          ],
        ),
      ],
    );
  }

  Widget _buildIcon(BuildContext context, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Icon(
        AppConstants.iconPassword,
        color: AppConstants.primaryColor,
        size: size * 0.48, // Scale icon with container
      ),
    );
  }

  Widget _buildContent(BuildContext context, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(context),
        const SizedBox(height: AppConstants.spacingXS),
        if (password.username.isNotEmpty && !compact)
          _buildUsername(context),
        if (!compact) const SizedBox(height: AppConstants.spacingXS),
        _buildUrl(context),
        const SizedBox(height: AppConstants.spacingXS),
        Row(
          children: [
            _buildCategory(context),
            const Spacer(),
            _buildDate(context),
          ],
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context, {double? fontSize}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            password.name,
            style: AppConstants.titleMedium.copyWith(
              fontSize: fontSize ?? ResponsiveBreakpoints.responsiveFontSize(
                context,
                mobile: 16,
                tablet: 17,
                desktop: 18,
              ),
              fontWeight: FontWeight.w600,
            ),
            maxLines: ResponsiveBreakpoints.isDesktop(context) ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildUsername(BuildContext context, {double? fontSize}) {
    if (password.username.isEmpty) return const SizedBox.shrink();
    
    return Text(
      password.username,
      style: AppConstants.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        fontSize: fontSize ?? ResponsiveBreakpoints.responsiveFontSize(
          context,
          mobile: 14,
          tablet: 15,
          desktop: 16,
        ),
      ),
      maxLines: ResponsiveBreakpoints.isDesktop(context) ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildUrl(BuildContext context, {double? fontSize}) {
    return Text(
      AppHelpers.getDomainFromUrl(password.url),
      style: AppConstants.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        fontSize: fontSize ?? ResponsiveBreakpoints.responsiveFontSize(
          context,
          mobile: 13,
          tablet: 14,
          desktop: 14,
        ),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCategory(BuildContext context, {double? fontSize}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveBreakpoints.responsive<double>(
          context,
          mobile: AppConstants.spacingS,
          tablet: 12,
          desktop: 14,
        ),
        vertical: ResponsiveBreakpoints.responsive<double>(
          context,
          mobile: AppConstants.spacingXS,
          tablet: 6,
          desktop: 8,
        ),
      ),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: Text(
        password.category,
        style: AppConstants.bodyMedium.copyWith(
          color: AppConstants.primaryColor,
          fontSize: fontSize ?? ResponsiveBreakpoints.responsiveFontSize(
            context,
            mobile: 12,
            tablet: 13,
            desktop: 14,
          ),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDate(BuildContext context, {double? fontSize}) {
    return Text(
      AppHelpers.formatDate(password.updatedAt),
      style: AppConstants.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        fontSize: fontSize ?? ResponsiveBreakpoints.responsiveFontSize(
          context,
          mobile: 12,
          tablet: 13,
          desktop: 14,
        ),
      ),
    );
  }

  Widget _buildTrailingActions(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            password.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: password.isFavorite ? AppConstants.primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            size: 20,
          ),
          onPressed: () => onAction?.call('favorite', password),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          splashRadius: 20,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActions(context),
            if (ResponsiveBreakpoints.isMobile(context))
              _buildArrow(context),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, child) {
        return PopupMenuButton<String>(
          onSelected: (value) => onAction?.call(value, password),
          icon: Icon(
            Icons.more_vert,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            size: ResponsiveBreakpoints.responsive<double>(
              context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            ),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy_password',
              child: Row(
                children: [
                  Icon(Icons.copy, size: 18),
                  SizedBox(width: 12),
                  Text('Copy Password'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'copy_username',
              child: Row(
                children: [
                  Icon(Icons.person, size: 18),
                  SizedBox(width: 12),
                  Text('Copy Username'),
                ],
              ),
            ),
            if (password.url.isNotEmpty)
              const PopupMenuItem(
                value: 'open_url',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 18),
                    SizedBox(width: 12),
                    Text('Open Website'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 12),
                  Text('Edit'),
                ],
              ),
            ),
            // Only show sync option if user is authenticated
            if (dataProvider.canSyncWithFirebase())
              const PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload, size: 18),
                    SizedBox(width: 12),
                    Text('Sync to Cloud'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArrow(BuildContext context) {
    if (!ResponsiveBreakpoints.isMobile(context)) return const SizedBox.shrink();
    
    return Icon(
      Icons.chevron_right,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      size: 20,
    );
  }
}
