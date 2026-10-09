# RegFinder V2

GitHub Pages-ready prototype.

V2 adds:
- Admin dashboard
- Editable fee tiers
- Manual inventory manager
- Order enquiry / reservation workflow
- Finder lead management
- CSV exports
- Browser persistence via localStorage
- Responsive storefront

Important: live DVLA scraping and payment collection are intentionally not enabled. Connect an authorised inventory source and server-side verification/fulfilment before taking live orders.

For a production deployment, replace localStorage with a database/auth backend and protect `/admin` with authentication.
