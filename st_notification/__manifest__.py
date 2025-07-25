{
    'name': 'Notification',
    'version': '1.0',
    "author": "Yustaf Pramsistya",
    'depends': ['base','firebase_push_notification'],
    'summary': "Mobile Notification",
    'description': """
        Mobile Notification with rules
    """,
    'category': 'Tools',
    'data': [
        "security/ir.model.access.csv",
        'views/wizard.xml',
        'views/rules.xml',
        'views/token.xml',
        'data/automated_actions.xml',
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
}
