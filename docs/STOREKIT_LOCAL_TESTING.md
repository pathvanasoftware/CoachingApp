# Local StoreKit Testing

Ascendra now includes a shared local StoreKit configuration at `Ascendra.storekit`.

## Included products

- `com.pathvana.ascendra.pro.monthly`
- `com.pathvana.ascendra.pro.yearly`

## How to test

1. Run the shared `CoachingApp` scheme in `Debug`.
2. Open the in-app subscription screen.
3. Purchase either Pro option.
4. Use `Restore Purchases` to re-sync the local transaction state.

## Notes

- The shared Debug scheme already points to `Ascendra.storekit`.
- The local config is for simulator and local device testing only.
- Production still requires the same product IDs in App Store Connect.
- Backend sync only promotes `starter` users to `professional`; it does not auto-downgrade enterprise or manually upgraded accounts.
