from odoo import api, fields, models, _
from odoo.exceptions import ValidationError
from firebase_admin import credentials, messaging
import logging
_logger = logging.getLogger(__name__)

class Base(models.AbstractModel):
    _inherit = 'base'

    def write(self, vals):
        res = super().write(vals)

        if vals.get('state',False) and self._name != 'ir.module.module':
            _logger.warning("self.name: "+self._name+", state: "+vals.get('state'))
            rules = self.env['push.notification.rules'].search([('model_name','=',self._name),('state','=',vals.get('state'))],limit=1)
            # self.direct_firebase(rules)
            self.mobile_post_notification(rules)
        return res

    def mobile_post_notification(self, rules=None):
        if not rules and self._name != 'mail.mail':
            rules = self.env['push.notification.rules'].search(
                [('model_name', '=', self._name), ('state', '=', self.state)], limit=1)
        if rules and self:
            users = rules.user_ids
            partners = users.mapped('partner_id')
            # link = rules.link % (self.id)
            message = rules.msg_body % (self.name)
            title = rules.msg_title + "#"+ str(rules.id)
            # message = '<p><strong>Kasbon Duedate.</strong><br/>Kasbon has passed the reporting due date :' + temp_msg + '</p>'
            odoobot = self.env.ref('base.partner_root')

            self.with_context(mark_so_as_sent=False) \
                .message_post(subject=title, body=message, author_id=odoobot.id, partner_ids=partners.ids,
                              message_type='notification',add_sign=False)

        return

    def direct_firebase(self, rules):
        if rules:
            users = rules.group_ids.mapped('users')
            partners = users.mapped('partner_id')
            link = rules.link % (self.id)
            body = rules.msg_body % (self.name)
            notif = self.env['mobile.app.push.notification'].sudo().create({
                'name': rules.msg_title,
                'body': body,
                'link': link,
                'send_notification_to': 'to_specefic',
                'partner_ids': partners,
            })
            notif.send_notification()
        return

class NotificationRules(models.Model):
    _name = 'push.notification.rules'
    _description = "Push notification with rules"

    name = fields.Char(string="Description")
    model_id = fields.Many2one('ir.model', string='Model', required=True, ondelete='cascade')
    model_name = fields.Char(string='Model name', related='model_id.model', store=True)
    state = fields.Char(string='State', required=True)
    domain = fields.Char(string='Domain')
    # group_ids = fields.Many2many('res.groups', string='Group', required=False)
    user_ids = fields.Many2many('res.users', string='Users', required=True)
    link = fields.Char(string='URL')
    msg_title = fields.Char(string='Title')
    msg_body = fields.Char(string='Message')
    note = fields.Char(string='Note')

class FirebaseToken(models.Model):
    _name = 'push.notification.token'
    _description = "Token login"
    _order = 'date desc, id desc'

    date = fields.Datetime(string='Date', default=fields.Datetime.now)
    token = fields.Char(string='Token')
    user_id = fields.Many2one('res.users', string='User', compute='get_token_user', store=True)
    partner_id = fields.Many2one('res.partner', string='Partner', related='user_id.partner_id', store=True)

    @api.depends('token')
    def get_token_user(self):
        for x in self:
            # Pertama cek di mail.firebase untuk mendapatkan user
            firebase_token = self.env['mail.firebase'].search([('token','=',x.token)], limit=1)
            if firebase_token and firebase_token.user_id:
                x.user_id = firebase_token.user_id.id
            else:
                # Fallback ke logic lama
                exist = self.env['push.notification.token'].search([('token','=',x.token),('user_id','!=',False)], limit=1)
                if exist:
                    x.user_id = exist.user_id and exist.user_id.id or False
                else:
                    x.user_id = False

    def write(self, vals):
        """Override write method to sync with mail.firebase"""
        res = super().write(vals)
        
        # Jika user_id di-update, sync dengan mail.firebase
        if 'user_id' in vals and vals['user_id']:
            for record in self:
                firebase_token = self.env['mail.firebase'].search([('token','=',record.token)], limit=1)
                if firebase_token and not firebase_token.user_id:
                    firebase_token.sudo().write({
                        'user_id': vals['user_id'],
                        'partner_id': self.env['res.users'].browse(vals['user_id']).partner_id.id
                    })
        
        return res

    @api.model
    def create(self, vals):
        """Override create method to auto-match user if possible"""
        # Cek apakah token sudah ada di mail.firebase
        if 'token' in vals:
            firebase_token = self.env['mail.firebase'].search([('token','=',vals['token'])], limit=1)
            if firebase_token and firebase_token.user_id and 'user_id' not in vals:
                vals['user_id'] = firebase_token.user_id.id
                
        return super().create(vals)

    def action_auto_match_users(self):
        """Action button untuk auto-match users yang belum ada"""
        tokens_without_user = self.search([('user_id', '=', False)])
        matched_count = 0
        
        for token_record in tokens_without_user:
            firebase_token = self.env['mail.firebase'].search([('token','=',token_record.token)], limit=1)
            if firebase_token and firebase_token.user_id:
                token_record.write({'user_id': firebase_token.user_id.id})
                matched_count += 1
        
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Auto Match Complete'),
                'message': _('%d tokens matched with users') % matched_count,
                'type': 'success',
            }
        }
