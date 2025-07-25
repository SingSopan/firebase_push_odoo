# -*- coding: utf-8 -*-

import json
import logging
from odoo import http, _
from odoo.http import request

_logger = logging.getLogger(__name__)


class FirebaseTokenController(http.Controller):

    @http.route('/mobile/token/register', type='json', auth='user', methods=['POST'], csrf=False)
    def register_firebase_token(self, **kwargs):
        """
        Endpoint untuk menerima token Firebase dari mobile app
        Parameters:
        - token: Firebase token dari device
        - os: Operating system (android/ios)
        """
        try:
            data = json.loads(request.httprequest.data.decode('utf-8'))
            token = data.get('token')
            os_type = data.get('os', 'android')
            
            if not token:
                return {'status': 'error', 'message': 'Token is required'}
            
            user = request.env.user
            partner = user.partner_id
            
            # Cek apakah token sudah ada untuk user ini
            existing_token = request.env['mail.firebase'].sudo().search([
                ('token', '=', token),
                ('user_id', '=', user.id)
            ], limit=1)
            
            if not existing_token:
                # Cek jika token ada tapi dengan user lain, hapus dulu
                existing_other_user = request.env['mail.firebase'].sudo().search([
                    ('token', '=', token)
                ], limit=1)
                if existing_other_user:
                    existing_other_user.sudo().unlink()
                
                # Buat record firebase token baru
                firebase_token = request.env['mail.firebase'].sudo().create({
                    'user_id': user.id,
                    'partner_id': partner.id,
                    'token': token,
                    'os': os_type
                })
                _logger.info(f"Firebase token created for user {user.name}: {token}")
            else:
                # Update OS jika berbeda
                if existing_token.os != os_type:
                    existing_token.sudo().write({'os': os_type})
                _logger.info(f"Firebase token already exists for user {user.name}")
            
            # Buat atau update record di push.notification.token juga
            notification_token = request.env['push.notification.token'].sudo().search([
                ('token', '=', token)
            ], limit=1)
            
            if notification_token:
                # Update user_id jika belum ada atau berbeda
                if not notification_token.user_id or notification_token.user_id.id != user.id:
                    notification_token.sudo().write({'user_id': user.id})
                    _logger.info(f"Updated notification token with user: {user.name}")
            else:
                # Buat notification token baru
                request.env['push.notification.token'].sudo().create({
                    'token': token,
                    'user_id': user.id,
                    'date': request.env['ir.fields'].Datetime.now()
                })
                _logger.info(f"Created notification token for user: {user.name}")
            
            return {
                'status': 'success', 
                'message': 'Token registered successfully',
                'user_id': user.id,
                'user_name': user.name
            }
            
        except Exception as e:
            _logger.error(f"Error registering firebase token: {str(e)}")
            return {'status': 'error', 'message': str(e)}

    @http.route('/mobile/token/update', type='json', auth='user', methods=['POST'], csrf=False)
    def update_firebase_token(self, **kwargs):
        """
        Endpoint untuk update token Firebase dari mobile app
        """
        try:
            data = json.loads(request.httprequest.data.decode('utf-8'))
            old_token = data.get('old_token')
            new_token = data.get('new_token')
            os_type = data.get('os', 'android')
            
            if not old_token or not new_token:
                return {'status': 'error', 'message': 'Both old_token and new_token are required'}
            
            user = request.env.user
            
            # Update di mail.firebase
            firebase_token = request.env['mail.firebase'].sudo().search([
                ('token', '=', old_token),
                ('user_id', '=', user.id)
            ], limit=1)
            
            if firebase_token:
                firebase_token.sudo().write({
                    'token': new_token,
                    'os': os_type
                })
                
            # Update di push.notification.token
            notification_token = request.env['push.notification.token'].sudo().search([
                ('token', '=', old_token)
            ], limit=1)
            
            if notification_token:
                notification_token.sudo().write({'token': new_token})
            
            return {'status': 'success', 'message': 'Token updated successfully'}
            
        except Exception as e:
            _logger.error(f"Error updating firebase token: {str(e)}")
            return {'status': 'error', 'message': str(e)}

    @http.route('/mobile/token/info', type='json', auth='user', methods=['GET'], csrf=False)
    def get_token_info(self, **kwargs):
        """
        Endpoint untuk mendapatkan info token user saat ini
        """
        try:
            user = request.env.user
            tokens = request.env['mail.firebase'].sudo().search([
                ('user_id', '=', user.id)
            ])
            
            token_list = []
            for token in tokens:
                token_list.append({
                    'token': token.token,
                    'os': token.os,
                    'id': token.id
                })
            
            return {
                'status': 'success',
                'user_id': user.id,
                'user_name': user.name,
                'tokens': token_list
            }
            
        except Exception as e:
            _logger.error(f"Error getting token info: {str(e)}")
            return {'status': 'error', 'message': str(e)}
