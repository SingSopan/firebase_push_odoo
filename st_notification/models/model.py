from odoo import api, fields, models, _
from odoo.exceptions import ValidationError
from firebase_admin import credentials, messaging
import logging
_logger = logging.getLogger(__name__)

class Picking(models.Model):
    _inherit = "stock.picking"

    def _compute_state(self):
        res = super()._compute_state()
        for x in self:
            x.write({'state': x.state})
        return res