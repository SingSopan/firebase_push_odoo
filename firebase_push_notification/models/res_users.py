# -*- coding: utf-8 -*-

from odoo import models, fields, api, _
from odoo.http import request
import logging

_logger = logging.getLogger(__name__)


class ResUsers(models.Model):
    _inherit = 'res.users'

    def _check_session_firebase_token(self):
        """Method untuk check dan sync firebase token dari session"""
        if hasattr(request, 'session') and request.session.get('firebase_token'):
            firebase_token = request.session.get('firebase_token')
            os_type = request.session.get('device_os', 'android')
            
            # Check if token already exists for this user
            existing_token = self.env['mail.firebase'].sudo().search([
                ('token', '=', firebase_token),
                ('user_id', '=', self.id)
            ], limit=1)
            
            if not existing_token:
                # Create new firebase token record
                self.env['mail.firebase'].sudo().create({
                    'user_id': self.id,
                    'partner_id': self.partner_id.id,
                    'token': firebase_token,
                    'os': os_type
                })
                _logger.info(f"Auto-created firebase token for user {self.name}")
            
            # Sync with notification token
            notification_token = self.env['push.notification.token'].sudo().search([
                ('token', '=', firebase_token)
            ], limit=1)
            
            if notification_token and not notification_token.user_id:
                notification_token.sudo().write({'user_id': self.id})
                _logger.info(f"Auto-matched notification token for user {self.name}")

    @api.model
    def authenticate(self, db, login, password, user_agent_env):
        """Override authenticate to handle firebase token"""
        uid = super().authenticate(db, login, password, user_agent_env)
        
        if uid and hasattr(request, 'session'):
            # Get user and check for firebase token
            user = self.browse(uid)
            user._check_session_firebase_token()
            
        return uid
