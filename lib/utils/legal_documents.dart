String _todayYmd() {
  final now = DateTime.now();
  String two(int x) => x.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}

class LegalDocuments {
  static const String _supportEmail = 'support@proservehub.app';

  static String help() {
    return '''Help

If you need help with ProServe Hub:

- For app issues: email $_supportEmail with the device type, account email, and what happened.
- For account issues: use “Set password” to reset your password or email $_supportEmail.
- For payment, lead, or escrow issues: include the job, invoice, or payment reference shown in the app.

We review support requests in the order received and prioritize account access, active jobs, payment, lead-credit, and safety issues.

Last updated: ${_todayYmd()}
''';
  }

  static String privacyPolicy() {
    return '''Privacy Policy

Last updated: ${_todayYmd()}

This Privacy Policy describes how ProServe Hub (“we”, “us”) collects, uses, and shares information when you use the app.

Information we collect
- Account info: email, name, and profile details you provide.
- Job requests: service type, description, location/ZIP, budget, and related messages.
- Photos you upload: images you attach to job requests or project updates.
- Usage data: basic app diagnostics and logs to help us improve reliability.

How we use information
- Provide the service (create job requests, match pros, messaging).
- Prevent fraud and protect users.
- Improve features and fix bugs.
- Communicate important updates.

Sharing
- With service professionals you choose to contact or hire.
- With vendors that help operate the app (hosting, analytics, payments), under appropriate safeguards.
- If required by law, or to protect rights and safety.

Data retention
We retain information as long as needed to provide the service and meet legal/accounting requirements. You can request deletion through “Delete my account data”.

Your choices
- You can update certain profile details in the app.
- You can request deletion of your account data.

Security
We use reasonable safeguards to protect data, but no system is 100% secure.

Contact
Email $_supportEmail.

Disclaimer
This is a general template and may not be sufficient for your jurisdiction or business model. Have a qualified attorney review before publishing.
''';
  }

  static String termsOfUse() {
    return '''Terms of Use

Last updated: ${_todayYmd()}

By using ProServe Hub, you agree to these Terms.

1. The service
ProServe Hub helps customers post job requests and connect with service professionals. We do not guarantee outcomes, pricing, or availability.

2. Accounts
You are responsible for your account and for keeping your login credentials secure.

3. User content
You are responsible for content you submit (job descriptions, photos, messages). Do not submit illegal, harmful, or infringing content.

4. Payments
If payments are offered in-app, additional terms may apply. Prices and fees may change.

5. Disputes
Customers and professionals are responsible for resolving disputes. We may provide tools, but we are not a party to the contract between users.

6. Prohibited use
Do not misuse the service, attempt unauthorized access, or interfere with app operation.

7. Termination
We may suspend or terminate accounts that violate these Terms or applicable laws.

8. Disclaimer of warranties
The app is provided “as is” without warranties of any kind.

9. Limitation of liability
To the maximum extent permitted by law, we are not liable for indirect or consequential damages.

Contact
Email $_supportEmail.

Disclaimer
This is a general template and may not be sufficient for your jurisdiction or business model. Have a qualified attorney review before publishing.
''';
  }

  static String caNoticeAtCollection() {
    return '''CA Notice at Collection

Last updated: ${_todayYmd()}

If you are a California resident, this notice explains the categories of personal information collected and why.

Categories we may collect
- Identifiers (name, email)
- Commercial information (job requests and related transactions)
- Internet or network activity (basic app usage)
- User content (messages, photos you upload)

Purposes
- Providing the service and customer support
- Safety, security, and fraud prevention
- Improving app performance and features

Your rights
You may have rights to access, delete, or correct certain information. You may also have the right to opt out of certain “sharing” as defined by CA law.

Use “Do not sell or share my info” and “Delete my account data” to submit requests.

Disclaimer
This is a general template and may not be sufficient for your jurisdiction or business model. Have a qualified attorney review before publishing.
''';
  }

  static String doNotSellOrShare() {
    return '''Do not sell or share my info

Last updated: ${_todayYmd()}

If you want to opt out of “sale” or “sharing” of personal information (as defined by some privacy laws), you can submit a request here.

How to request
- Email $_supportEmail with the subject “Opt-out request”.
- Include the email address on your ProServe Hub account.
- We will confirm receipt and process eligible requests under applicable law.

Disclaimer
This is a general template and may not be sufficient for your jurisdiction or business model. Have a qualified attorney review before publishing.
''';
  }

  static String reportTechnicalProblem() {
    return '''Report a technical problem

Last updated: ${_todayYmd()}

To report an issue, include:
- What you were doing
- What you expected to happen
- What actually happened
- Screenshots (if possible)
- The time it happened

Send reports to $_supportEmail.

Tip: Your app already saves a local error log file. If you can access it, attach it to your report.
''';
  }

  static String deactivateAccount() {
    return '''Deactivate account

Last updated: ${_todayYmd()}

Deactivating your account disables access to the app.

Before requesting deactivation:
- Complete, cancel, or resolve any active jobs.
- Save copies of invoices, proposals, contracts, or job summaries you need.

To request deactivation, email $_supportEmail with the subject “Deactivate account” from the email address on your account. We may retain records that are required for payments, disputes, fraud prevention, accounting, legal compliance, or platform safety.

Disclaimer
This is a general template and may not be sufficient for your jurisdiction or business model. Have a qualified attorney review before publishing.
''';
  }

  static String deleteAccountData() {
    return '''Delete my account data

Last updated: ${_todayYmd()}

You can request deletion of your account data.

To request deletion, email $_supportEmail with the subject “Delete my account data” from the email address on your account. We will review the request and delete eligible account data. Some records may be retained when needed for active jobs, payments, disputes, security, fraud prevention, accounting, legal compliance, or tax obligations.

Deletion may affect access to job history, messages, invoices, proposals, contracts, reviews, portfolios, saved clients, lead credits, and subscription-related records.

Disclaimer
This is a general template and may not be sufficient for your jurisdiction or business model. Have a qualified attorney review before publishing.
''';
  }
}
