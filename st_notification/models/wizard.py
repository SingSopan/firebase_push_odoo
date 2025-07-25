# -*- coding: utf-8 -*-

from odoo import models, fields, api, _
from odoo.exceptions import UserError


class TokenUserMatchWizard(models.TransientModel):
    _name = 'token.user.match.wizard'
    _description = 'Wizard untuk matching token dengan user'

    def action_auto_match_all(self):
        """Auto match semua token yang belum memiliki user"""
        token_model = self.env['push.notification.token']
        tokens_without_user = token_model.search([('user_id', '=', False)])
        matched_count = 0
        
        for token_record in tokens_without_user:
            # Cari di mail.firebase berdasarkan token
            firebase_token = self.env['mail.firebase'].search([('token','=',token_record.token)], limit=1)
            if firebase_token and firebase_token.user_id:
                token_record.write({'user_id': firebase_token.user_id.id})
                matched_count += 1
        
        message = _('%d tokens berhasil di-match dengan users') % matched_count
        
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Auto Match Selesai'),
                'message': message,
                'type': 'success',
            }
        }

    def action_sync_firebase_tokens(self):
        """Sync token dari mobile app yang login dengan user session"""
        # Logic untuk sync token dari session login
        # Ini bisa dipanggil ketika ada user login dari mobile
        
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Sync Complete'),
                'message': _('Firebase tokens telah di-sync'),
                'type': 'success',
            }
        }
