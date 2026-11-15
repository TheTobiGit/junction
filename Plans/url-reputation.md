# URL reputation in Junction

Research date: 15 November 2026. Prices are USD. Sources are official provider pages. Recommendations are proposals, not implementation decisions. No app, build, live scan, API account, or performance test was run.

Start with local checks and user-imported threat lists. Add remote checks as an explicit option. Do not send every clicked link to a scanner.

## The privacy boundary

The README promises “Local. No account, no telemetry, no network call.” That claim is already wider than the code supports. See [README.md:30](/Users/zee/Developer/Github/cumpany/junction/README.md:30).

| Mode | What leaves the Mac | Can keep the literal promise? |
| --- | --- | --- |
| Existing heuristics and user host rules | Nothing for the check | Yes |
| Local full-URL, full-hash, or domain list imported from a file | Nothing for the check | Yes, if the list licence permits use |
| List downloaded by Junction | Provider sees IP, download time, account or key | No. It can promise no per-link network check |
| Local Google hash-prefix list | Updates plus prefix requests on possible matches | No. A prefix hit alone is not a confirmed threat |
| Remote URL lookup | Provider receives the URL or its identifier | No. Needs consent and clear disclosure |
| Remote browser scan | Scanner receives URL and visits the destination and page resources | No. Can publish sensitive links or trigger link actions |
| Filtering DNS | Resolver receives hostname and network metadata, not URL path or query | No. Domain protection only |

The distinctions above follow the API designs below. A full hash avoids sending a readable URL. It does not make a known URL anonymous: the provider can associate a known hash with its stored URL. This is a privacy inference.

## Current code and integration points

These anchors refer to the current checkout. No source file was changed.

| Code | Current behavior | Proposed fit |
| --- | --- | --- |
| [URLRiskAssessor.swift:35](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/URLProcessing/URLRiskAssessor.swift:35) | Synchronous heuristics for shorteners, credentials, HTTP, IP hosts, internationalized hosts, look-alikes, unusual suffixes and ports. No reputation provider | Keep this pure and local. Combine its flags with a separate reputation result |
| [URLRiskAssessor.swift:24](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/URLProcessing/URLRiskAssessor.swift:24) | `RiskFlag` has level, title and detail | Add a separate typed result with provider, scope, evidence date and expiry. Do not encode policy in titles |
| [PickerViewModel.swift:11](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/PickerViewModel.swift:11), [line 92](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/PickerViewModel.swift:92), [PickerURLRisk:420](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/PickerViewModel.swift:420) | Immutable flags computed during initialization. Check selects raw or cleaned URL using opening settings | Publish async reputation state separately. Bind each result to the exact URL that will open |
| [RiskChip.swift:17](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/RiskChip.swift:17), [line 50](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/RiskChip.swift:50) | Chip shows highest flag; popover lists details | Show suspected phishing or malware, provider, matched URL/host, evidence age, and allowed actions |
| [PickerView.swift:349](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/PickerView.swift:349) | Separates internationalized-host flags from other flags | Put reputation in the general risk area. Keep host spelling warnings distinct |
| [ShortenerExpander.swift:56](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/URLProcessing/ShortenerExpander.swift:56), [line 87](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/URLProcessing/ShortenerExpander.swift:87) | Cached expansion; default two-second timeout; HEAD, then ranged GET fallback | Expansion itself contacts the shortener and redirect destinations. Assess both supplied link and resolved destination. Strict offline mode must disable expansion |
| [LinkPreviewFetcher.swift:76](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Links/LinkPreviewFetcher.swift:76), [line 98](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Links/LinkPreviewFetcher.swift:98), [line 133](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Links/LinkPreviewFetcher.swift:133) | Fetches HTML and a favicon. Default request timeout is 2.5 seconds; resource timeout is ten seconds | Local risk policy must run before preview fetch. A preview contacts a possibly hostile site before the user opens it |
| [HostFaviconFetcher.swift:56](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Links/HostFaviconFetcher.swift:56), [line 63](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Links/HostFaviconFetcher.swift:63) | Tries destination favicon, then DuckDuckGo icon service | Disclose host sharing with DuckDuckGo. Disable both remote paths in strict offline mode |
| [PickerViewModel.swift:101](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/PickerViewModel.swift:101) | Starts preview and host-icon work during initialization | Add local assessment and privacy-mode checks before these calls |
| [RulesModel.swift:75](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Rules/RulesModel.swift:75), [AppDelegate.swift:500](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AppDelegate.swift:500) | `RuleAction.block` already shows a blocked notice and records a blocked outcome | Reuse the notice and history outcome. Keep provider policy separate from user host rules |
| [AppDelegate.swift:495](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AppDelegate.swift:495) | Determines actual `urlToOpen` before rule action | Main routing assessment point, after local transformations and cleaning decisions |
| [AppDelegate.swift:108](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AppDelegate.swift:108), [line 377](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AppDelegate.swift:377) | Custom URL command and agent explicit-target paths open directly | A shared opening-policy gate must cover these paths |
| [AppDelegate.swift:415](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AppDelegate.swift:415), [line 465](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AppDelegate.swift:465), [line 511](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AppDelegate.swift:511) | App-scheme rewrites can launch native apps, including before ordinary rule handling | Apply policy to the source HTTP URL before rewriting. A gate only in `URLOpener` would miss these paths |
| [URLOpener.swift:27](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Browser/URLOpener.swift:27), [AppDelegate.swift:570](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AppDelegate.swift:570) | Browser/profile opening and supported incognito targets | Optional user policy can select a dedicated profile or supported private window |
| [PreviewWebViewFactory.swift:75](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/PreviewWebViewFactory.swift:75) | Builds a WebKit view and enables page JavaScript | WebKit fraud warnings can protect a loaded preview. They do not give Junction a preflight verdict |
| [JunctionCLI/main.swift:258](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionCLI/main.swift:258), [AppDelegate.swift:310](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AppDelegate.swift:310) | `inspect --json` uses local transforms and flags | Extend inspect with local reputation by default. Remote checks need a separate explicit option |
| [AgentProtocol.swift:18](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionCore/AgentProtocol.swift:18), [line 150](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionCore/AgentProtocol.swift:150), [line 161](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionCore/AgentProtocol.swift:161) | Codable request/response protocol. Inspect flags contain level, title and detail | Add optional reputation fields and an explicit check request. Preserve old decoder defaults |

## Service comparison

“Unknown” means the cited official material did not establish the point. No latency measurements were made. A network round trip is a design cost, not a measured response time or service guarantee. Open-source code does not grant rights to a provider's data.

### VirusTotal

| Item | Evidence and Junction fit |
| --- | --- |
| Checks and API | Aggregated URL/domain malware and phishing reports. REST with JSON and `x-apikey`. Read a URL object with `GET /api/v3/urls/{id}`; submit a URL for analysis separately. IDs can be SHA-256 or URL-safe Base64. [API overview](https://docs.virustotal.com/docs/api-overview), [URL objects](https://gtidocs.virustotal.com/reference/url-object) |
| Free and paid | Public API: 4 requests/minute and 500/day. Premium quota depends on licence. No public premium price verified. Public use excludes commercial products/services and business workflows that do not contribute new files. Premium is marketed for enrichment, not detection. A router that blocks links needs vendor confirmation even with a premium key. [Public versus premium](https://docs.virustotal.com/reference/public-vs-premium-api) |
| Desktop terms | Client scripts and integrations exist. This does not grant blanket rights for an automatic desktop protection product. API guidance also excludes use as an antivirus substitute. A free Junction download is not proof that workplace use qualifies. [API overview](https://docs.virustotal.com/docs/api-overview) |
| Privacy | Base64 sends the readable URL in reversible form. A SHA-256 report ID avoids that, but identifies a known record. Submissions share reports with the community and examining partners; submitted page content may reach premium customers. Some URL analysis queries antivirus partners. The docs do not establish that every read-only hash report lookup forwards the URL to partners. Mark that distinction unresolved. [How it works](https://docs.virustotal.com/docs/how-it-works) |
| Latency and offline | Existing report: network request. New analysis: asynchronous work. No measured latency. No public local-prefix database verified. Best fit: manual expert report lookup, subject to terms. Never submit automatically when a report is absent. [API overview](https://docs.virustotal.com/docs/api-overview) |

### Google Safe Browsing v4 and v5

| Item | Evidence and Junction fit |
| --- | --- |
| Threats and clients | Malware, social engineering and unwanted software. Docs address client applications; no browser-only restriction was found. This is suitable in principle for a non-browser router, subject to the same terms. [v5 overview](https://developers.google.com/safe-browsing/reference) |
| v4 Lookup | API key. JSON `POST /v4/threatMatches:find`, up to 500 URLs. Full URLs go to Google. One network request on a cache miss. [Lookup API](https://developers.google.com/safe-browsing/v4/lookup-api) |
| v4 Update | `threatListUpdates:fetch` downloads prefixes. `fullHashes:find` confirms local prefix matches. URLs require provider-specific canonicalization and host/path expressions. Local misses avoid per-link requests. Prefix hits require valid full-hash confirmation. [Update API](https://developers.google.com/safe-browsing/v4/update-api) |
| v5 shape | Keyed hash-list downloads and `GET /v5/hashes:search`, with four-byte prefixes. Raw-URL `urls.search` is documented at `v5alpha1`; do not assume it has the same maturity as the v5 hash endpoint. Real-time mode uses a likely-benign Global Cache; local-list mode queries on threat-prefix matches. [Overview and endpoint examples](https://developers.google.com/safe-browsing/reference), [local-list mode](https://developers.google.com/safe-browsing/reference/Local.List.Mode) |
| v5 privacy | Direct hash checks send prefixes and expose source IP to Google. Optional Oblivious HTTP separates the relay, which sees client IP, from Google's gateway, which sees the query. It remains network traffic. A production relay arrangement and its cost were not verified for Junction. [Gateway API](https://developers.google.com/safe-browsing/ohttp/reference) |
| Free and paid | Free for qualifying non-commercial use. The v4 quota page gives no universal numeric allocation; the project console shows it. A current universal v5 quota was not verified. Commercial use requires a separate agreement or Web Risk. [Usage restrictions](https://developers.google.com/safe-browsing/v4/usage-limits), [terms](https://developers.google.com/safe-browsing/terms) |
| Required notices | Use qualified warnings and provider attribution only for Google's findings. v4 warnings require a valid cached lookup or full-hash result. Current general terms require updated data within 30 minutes and permit Google to share URLs/content/metadata submitted through SearchUrls. Do not use stale imported Google prefixes as confirmed threats. [v4 restrictions](https://developers.google.com/safe-browsing/v4/usage-limits), [terms](https://developers.google.com/safe-browsing/terms) |
| Offline and timing | Local misses and valid cached confirmations can be local. Unconfirmed prefix hits remain unknown offline. No measured latency. Neither v4 Update nor v5 local-list mode satisfies the literal no-network promise. [v4 Update](https://developers.google.com/safe-browsing/v4/update-api), [v5 local-list mode](https://developers.google.com/safe-browsing/reference/Local.List.Mode) |

### Google Web Risk

| Item | Evidence and Junction fit |
| --- | --- |
| Checks and client use | Commercial client API for malware, social engineering and unwanted software. No browser-only restriction found. Returned information must not be redistributed. Use each user's licensed project; do not publish a Junction threat feed from responses. [Overview](https://docs.cloud.google.com/web-risk/docs/overview) |
| API and auth | API-key REST examples: `GET /v1/uris:search` for one URL; `threatLists:computeDiff` and `hashes:search` for Update. Requires a configured Google Cloud project. [Lookup](https://docs.cloud.google.com/web-risk/docs/lookup-api), [Update](https://docs.cloud.google.com/web-risk/docs/update-api) |
| Price | Lookup-only: first 100,000/month/account free, then $0.50/1,000. Update diffs: free. Update hash confirmation: $50/1,000, with no confirmation free tier listed. Calling computeDiff also changes URI confirmation pricing to $50/1,000. These are materially different prices. [Pricing](https://cloud.google.com/web-risk/pricing) |
| Privacy | Lookup sends full URL to Google. Update sends matching hash prefixes; downloaded lists permit local misses. No public independent-relay option was verified. Lookup timing has no guarantee in the overview. [Overview](https://docs.cloud.google.com/web-risk/docs/overview) |
| Terms and sharing | Warnings require fresh data, attribution and accuracy notice. The explicit third-party sharing clause covers Brand Phishing Protection, Evaluate and Submission APIs. It does not establish that ordinary Lookup requests are public submissions. Do not add those other methods silently. Exact Lookup retention and partner forwarding remain unverified. [Service terms, section 47](https://cloud.google.com/terms/service-terms) |
| Offline fit | Prefix misses are local; prefix matches need confirmation or unexpired cached full hashes. Price example: 2,000 hash confirmations cost $100. Use opt-in with the user's key, budget cap and expiry checks. [Update](https://docs.cloud.google.com/web-risk/docs/update-api), [pricing](https://cloud.google.com/web-risk/pricing) |

### urlscan.io

| Item | Evidence and Junction fit |
| --- | --- |
| Checks and API | Remote browser analysis, page requests, redirects and verdicts. API-key submission, search and result retrieval. Search an existing scan separately from starting a new one. [API introduction](https://docs.urlscan.io/pages/api-intro) |
| Free limits | Published daily free quotas: 5,000 public scans, 1,000 unlisted, 50 private, 1,000 searches and 10,000 result reads. Per-minute/hour limits also apply; use account quota endpoint and headers. [Pricing](https://urlscan.io/pricing/), [rate limits](https://docs.urlscan.io/pages/api-rate-limits) |
| Paid price | Automate: $5,000/year. Professional: $1,250/month or $12,500/year. Larger plans cost more. These plans are far beyond a default link-router dependency. [Pricing](https://urlscan.io/pricing/) |
| Privacy | Scanner receives full URL and visits it. Public scans are public. Unlisted scans are visible to vetted researchers and security companies in Pro. Private scans have restricted visibility; sharing the scan ID can expose them. Unlisted is not private. [Visibility](https://docs.urlscan.io/pages/visibility) |
| Terms | Docs support open-source integrations. General terms require express written permission for commercial service use. Commercial customers have separate terms. A personal key is not permission to redistribute reports or offer a shared service. [API introduction](https://docs.urlscan.io/pages/api-intro), [terms](https://urlscan.io/terms/) |
| Latency and offline | Submission and report retrieval are separate operations. No completion-time guarantee verified. No public local/hash-prefix option. Keep it a manual investigation action with explicit visibility. Never downgrade private to public when quota runs out. [API introduction](https://docs.urlscan.io/pages/api-intro), [visibility](https://docs.urlscan.io/pages/visibility) |

### abuse.ch URLhaus and ThreatFox

| Item | URLhaus | ThreatFox |
| --- | --- | --- |
| Checks | Malware delivery URLs. Not a general phishing database. [API](https://urlhaus.abuse.ch/api/) | Malware indicators, including domains, URLs and IP:port values. Filter by indicator type and confidence. [API](https://threatfox.abuse.ch/api/) |
| API, auth, limits | Auth-Key required. Current export URLs include the key. CSV/JSON dumps, active URLs, host lists and RPZ. Dumps regenerate every five minutes; do not fetch more often. Exact current query routes are login-gated. [API](https://urlhaus.abuse.ch/api/) | Auth-Key header; JSON POST to `https://threatfox-api.abuse.ch/api/v1/`. `get_iocs` covers up to seven days; full JSON/CSV exports are separate. Entries older than six months expire from API/export. [API](https://threatfox.abuse.ch/api/) |
| Cost and desktop terms | Free authenticated not-for-profit fair use. No fixed public query quota or paid price verified. Commercial needs may require a Spamhaus subscription. Bundling and redistribution permission not verified. [Terms](https://abuse.ch/terms-of-use/) | Same platform terms. Do not assume the old unrestricted-free position still applies. [Terms](https://abuse.ch/terms-of-use/) |
| Privacy | Feed download sends no clicked URL. Remote URL/host query reveals the queried value to abuse.ch. Exact lookup retention or partner forwarding unverified. Use local exports. [API](https://urlhaus.abuse.ch/api/) | Local export matching reveals no clicked link. `search_ioc` reveals the indicator to abuse.ch. Do not submit user links as new indicators. Partner handling of lookup logs unverified. [API](https://threatfox.abuse.ch/api/) |
| Latency and offline | Local full-URL list can give an exact match offline. Host lists lose path scope. Runtime lookup latency unmeasured. [API](https://urlhaus.abuse.ch/api/) | Local typed matches work offline. Do not resolve hosts to IPs merely to match a feed in offline mode. No public prefix protocol verified. [API](https://threatfox.abuse.ch/api/) |

### PhishTank and OpenPhish

| Item | PhishTank | OpenPhish |
| --- | --- | --- |
| Checks and API | Community-verified phishing. JSON/XML POST `https://checkurl.phishtank.com/checkurl/`; full URL, optional application key, required descriptive User-Agent. [API](https://www.phishtank.org/api_info.php) | Phishing URL feed. Community text file; paid CSV/JSON with more context. [Feeds](https://www.openphish.com/phishing_feeds.html) |
| Free limits and cost | Free API with dynamic limits in response headers; HTTP 509 on excess. Hourly downloadable databases; key requested for automated downloads. No published paid tier verified. [API](https://www.phishtank.org/api_info.php), [downloads](https://www.phishtank.org/developer_info.php) | Free limited Community feed updates every 12 hours. Premium/Platinum update every five minutes. Paid price requires a quote. Public feed needs no key; paid delivery auth unverified. [Feeds](https://www.openphish.com/phishing_feeds.html) |
| Desktop terms | Archived terms allow commercial API data use. Current page explicitly points to Cisco's current agreement. Do not treat archived text as current licence clearance. New user registration is disabled, so new-key access is uncertain. [Terms](https://phishtank.org/terms.php), [current agreement](https://www.cisco.com/c/en/us/about/legal/cloud-and-software/end_user_license_agreement.html), [registration](https://phishtank.org/register.php) | Current terms require written consent for commercial security, detection, development, automation and customer protection. Free/open-source distribution does not settle eligibility. Redistribution rights unverified. [Terms](https://www.openphish.com/terms.html) |
| Privacy | Lookup sends full URL to Cisco/PhishTank. Download matching sends no clicked URL. Lookup publication, partner sharing and retention not verified. [API](https://www.phishtank.org/api_info.php), [downloads](https://www.phishtank.org/developer_info.php) | Feed download sends no clicked URL to OpenPhish or the Community feed host, GitHub. Do not use the report-phishing address as a lookup mechanism. [Feeds](https://www.openphish.com/phishing_feeds.html) |
| Latency and offline | Hourly list supports offline exact URL matching. Remote lookup adds a round trip; no latency guarantee verified. [Downloads](https://www.phishtank.org/developer_info.php) | Local text/JSON/CSV lookup is offline. No hash-prefix service verified. Community freshness can lag by 12 hours before local update delay. [Feeds](https://www.openphish.com/phishing_feeds.html) |

### Cloudflare URL Scanner, including Radar

| Item | Evidence and Junction fit |
| --- | --- |
| Checks and API | Remote page execution, requests, redirects, screenshots and maliciousness verdicts. Bearer token with Account URL Scanner Edit permission and account ID. POST `/accounts/{id}/urlscanner/v2/scan`; GET result by scan ID. [Scanner docs](https://developers.cloudflare.com/radar/investigate/url-scanner/) |
| Limits and cost | Free/Radar: 5,000 public scans/month, no unlisted allowance, one request/ten seconds, last 50 scans in history. Self-serve: 5,000 public plus 500 unlisted. Enterprise: 10,000 plus 5,000. Scanner-specific paid dollar price not verified. [Limits](https://developers.cloudflare.com/security-center/investigate/scan-limits/) |
| Privacy | Full URL goes to Cloudflare and its remote browser. Default is public. Unlisted scans remain accessible to people with the ID. Docs give 12-month successful-scan retention. No private-scan level documented here. [Scanner docs](https://developers.cloudflare.com/radar/investigate/url-scanner/) |
| Terms and timing | General API access is documented, but no explicit free/open-source desktop redistribution grant was verified. Results are async; docs suggest polling every 10 to 30 seconds. No offline/hash-prefix option. Use manual investigation only. [Scanner docs](https://developers.cloudflare.com/radar/investigate/url-scanner/) |

### Spamhaus DBL and DNS blocklists

| Item | Evidence and Junction fit |
| --- | --- |
| Checks and API | DBL checks low-reputation domains. DNS A/TXT queries under DBL zones; DQS uses a query key. IP lists such as ZEN check different evidence and are not URL verdicts. [Zones](https://docs.spamhaus.com/datasets/docs/source/10-data-type-documentation/datasets/040-zones.html) |
| Free and paid | Public mirrors require qualifying non-commercial use and identifiable resolver traffic. Current policy gives no fixed public-mirror numeric quota. Separate free DQS terms allow qualifying small non-commercial users up to 100,000 queries/day. Commercial subscriptions and datafeeds exist; dollar price unverified. [Mirror policy](https://www.spamhaus.org/blocklists/dnsbl-fair-use-policy/), [DQS terms](https://www.spamhaus.com/sign-up-terms-and-conditions/) |
| Desktop terms | Free DQS bars providing access to third parties and redistribution. Ship no shared key. Per-user entitlement or an integration agreement is needed. Do not infer an open-source exception. [Terms](https://www.spamhaus.com/sign-up-terms-and-conditions/) |
| Privacy and timing | Hostname goes to the selected recursive resolver and Spamhaus. A DQS query also contains the key. Path and query stay local. DNS round trip or cache hit; no measured latency. Generic public resolvers may be rejected. [Usage FAQ](https://www.spamhaus.org/faqs/dnsbl-usage/) |
| Errors and offline | `127.255.255.*` responses are query errors, not threat matches. Parse category codes. A downloadable licensed datafeed can support local operation; no freely redistributable DBL snapshot or hash-prefix option verified. [Error codes](https://www.spamhaus.org/resource-hub/dnsbl/spamhaus-dnsbl-return-codes-technical-update/), [access methods](https://www.spamhaus.org/faqs/dnsbl-usage/) |

### Quad9 and other filtering DNS

| Service | Access, cost and scope | Privacy, terms and offline fit |
| --- | --- | --- |
| Quad9 | Free public domain filtering, including malware and phishing. DNS, encrypted DNS options and a blocked-domain tester. No key. No fixed free numeric quota or paid desktop API tariff verified. [Service](https://quad9.net/), [FAQ](https://docs.quad9.net/FAQs/) | Receives hostnames, not full URLs. Policy says no identifying user data is retained; limited threat-event counters can go to the analysts who supplied a matching indicator. No public offline threat list verified. No explicit mass desktop reputation-query licence verified. [Privacy policy](https://quad9.net/privacy/policy/) |
| Cloudflare 1.1.1.1 for Families | Free malware-filtering resolver at `1.1.1.2`, with encrypted DNS options. Standard `1.1.1.1` does not filter malware. No key; no fixed per-client quota or paid reputation tariff verified. [Setup](https://developers.cloudflare.com/1.1.1.1/setup/) | Cloudflare receives hostname and connection metadata. Families uses the resolver privacy commitments. No public offline database or explicit desktop reputation redistribution grant verified. [Privacy](https://developers.cloudflare.com/1.1.1.1/privacy/public-dns-resolver/) |

DNS latency depends on resolver location and cache state. It was not measured. DNS cannot distinguish a harmful path on a good host. It also cannot assess a numeric-IP URL through a hostname query. These are protocol limits.

Use a provider's blocked response and Extended DNS Error where available. A generic NXDOMAIN or SERVFAIL is not enough to label a URL malicious. Quad9 documents block indicators and DNSSEC failure separately. Its privacy policy also documents Extended DNS Error support. [FAQ](https://docs.quad9.net/FAQs/), [policy](https://quad9.net/privacy/policy/).

Suggest filtering DNS as a user-managed system/browser setting. A Junction-only probe does not force the opened browser to use that resolver. Browser encrypted DNS, a VPN or a proxy may use a different path. This is an integration inference. Do not change system DNS automatically.

### Apple's Safari and WebKit protection

| Item | Evidence and Junction fit |
| --- | --- |
| Safari | Safari can warn about suspected fraudulent sites. Its privacy notice describes calculated address information sent to Apple and Google, or Tencent for relevant regions. It says the actual address is not shared with the safe-browsing provider. This does not mean the destination website receives no request. [Safari privacy](https://www.apple.com/legal/privacy/data/en/safari/), [Mac settings](https://support.apple.com/guide/safari/ibrw1074/mac) |
| Third-party API | Public `WKPreferences.isFraudulentWebsiteWarningEnabled` controls warnings in a loaded `WKWebView`. It is available on macOS 10.15 onward and defaults to enabled in the public header. [Apple docs](https://developer.apple.com/documentation/webkit/wkpreferences), [WebKit header](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKPreferences.h) |
| Limits and fit | No standalone public Apple URL-verdict API, callable Safari list database, account quota, per-query price or offline export was verified. WebKit warning behavior is a platform feature, not a free reputation-data licence. No preflight latency promise verified. Do not load a hidden web view just to obtain a risk verdict |
| Junction use | Preserve or explicitly enable the WebKit preference for previews. Actual warning behavior needs a later runtime check. Routing to Safari leaves protection to Safari's settings. Junction cannot claim that Safari checked a URL before launch |

## Proposed Junction design

### Local core and explicit network modes

| Component | Proposed contract |
| --- | --- |
| Local assessment | Heuristics plus immutable, indexed snapshots. Return exact URL, domain or full-hash scope. A missing entry means “not listed”, never “safe” |
| Feed import | Accept user files first. Record source, licence, generation time, import time and expiry. Bound file size and decompression. Validate before atomic replacement; retain the last valid snapshot |
| Feed update | Separate opt-in setting and command. No click-dependent downloads. Use HTTPS, conditional downloads and provider cadence. Never log keyed export URLs |
| Remote provider | Off by default. Explain recipient, payload, sharing, price and account terms before enablement. Store a user's key in Keychain; do not embed an app-wide key |
| Strict offline mode | Disable reputation requests, feed updates, shortener expansion, HTML preview, web preview and remote favicons. Local-file import remains available |
| Result state | `notChecked`, `checking`, `listed`, `notListed`, `unknown`, `stale`, `error`. Include provider, category, matched scope, checked URL identity and validity deadline |

Full local lists can preserve the promise during checking. Auto-downloaded lists require narrower wording, such as “Links are checked on your Mac. List updates are optional.” Keeping the literal global promise requires no Junction network calls in that mode.

Hash prefixes require a different contract. Use Google's canonicalization and host/path expressions, not a generic hash of `absoluteString`. A prefix collision alone must not block opening. Offline confirmation is possible only with a still-valid cached full-hash result. Google's notice and freshness rules still apply.

### Keep the picker fast

| Stage | Proposed behavior |
| --- | --- |
| Receive and normalize | Run local transformations. Keep supplied, unwrapped, expanded and actual opening URL identities distinct. Never send file URLs, credentials, private hosts or internal names to reputation providers |
| First paint | Read a prepared local snapshot and cache. Show picker immediately. Proposed local-work budget: 5 ms; measure later. Cold list parsing must run outside this path |
| Background lookup | Start only after consent and a configured provider. Use an actor/service off the main actor. Deduplicate concurrent requests. Cancel work when its URL/picker generation is obsolete |
| Deadline | Proposed interactive network deadline: one second, with a firm resource timeout. Timeout means unknown. No retry loop in the picker. Respect provider backoff and quota headers |
| Cache | Key by provider, canonical URL/host, list version and threat type. Use positive and negative expiry from the provider. Bound entries. Keep sensitive URL keys hashed locally and avoid persistent browsing logs |
| Result update | Publish on the main actor only if the URL and generation still match. Do not move the selected browser row. Never reopen a dismissed picker or reroute a link already launched |
| Slow scanners | Show a separate investigation job. urlscan and Cloudflare scans must never be dependencies of picker display or normal opening |

A network check must never block picker display. There is a separate policy choice for opening: warn-only mode may open while the result is unknown. A user-selected strict policy can show the picker immediately, hold opening, then offer cancel or an explicit override. It cannot promise both instant automatic opening and a guaranteed fresh remote verdict.

### Verdicts and routing

| Evidence | Proposed response |
| --- | --- |
| Existing heuristic only | Keep the current chip. Do not call it provider-confirmed malware |
| Fresh exact URL or full-hash hit | Show a qualified warning with provider and age. Suppress preview fetches. Use the blocked notice if the user selected block policy |
| Domain hit | State domain scope. Do not silently convert a single malicious URL into a whole-host block |
| Prefix hit awaiting confirmation | Show checking or unknown. No threat claim based on the collision |
| Missing, expired or failed check | Show not checked, stale or unavailable. No green safety guarantee |
| Auto-route rule plus listed destination | Local policy can stop the route and show the picker or block notice. Apply it before every open path, including native schemes and explicit CLI targets |
| Requested private route | Use existing supported incognito handling. Show unsupported targets clearly. A private window is not malware isolation |
| Dedicated browser/profile | Optional user-selected route for unknown links. An ordinary profile is not an isolated security environment. A remote isolation provider needs a separate design, contract and consent |

Recheck local state on confirmation, including keyboard picks, remembered targets and multi-open. Relevant picker callbacks start at [PickerViewModel.swift:339](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/PickerViewModel.swift:339) and [line 369](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/Picker/PickerViewModel.swift:369). Centralize policy so these do not diverge from agent and rule routes.

Never publish a link as an automatic response to a threat warning. Scanner visits can consume one-time tokens or activate actions. Scrubbing the URL can change the resource being checked. Suppress sensitive submissions and ask for a deliberate manual action.

### CLI and agent socket

These commands and fields are proposed. They do not exist yet.

| Surface | Proposed addition |
| --- | --- |
| `junction inspect URL --json` | Remains local. Add reputation objects, snapshot age, match scope, policy result and `networkUsed: false` |
| `junction reputation check URL --provider NAME --online` | Explicit remote lookup. Require provider setup and saved consent. Do not submit a new scan on a missing report |
| `junction reputation import FILE` | Validate and import a local snapshot. Report counts, source, age and rejected records |
| `junction reputation update NAME` | Explicit network update. Report success, expiry, next allowed update and quota status |
| `junction reputation status` | Show enabled providers, snapshot versions, expiry and consent mode. Never return API keys |
| Socket request | Add `reputationCheck` with URL, provider, `allowNetwork`, deadline and request ID. Default `allowNetwork` to false. Never let a caller bypass app consent |
| Socket response | Return typed state, provider, checked identity, categories, match scope, evidence time, expiry, cache status and error code. Remote scan jobs need IDs and separate status requests |
| Opening policy | `open --in` and custom URL commands must use the same policy. Return a distinguishable blocked result so scripts do not interpret it as successful opening |

Extend Codable fields with defaults as used at [AgentProtocol.swift:185](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionCore/AgentProtocol.swift:185). The local socket already gets mode 0600 at [AgentServer.swift:61](/Users/zee/Developer/Github/cumpany/junction/Sources/JunctionApp/App/AgentServer.swift:61). Preserve that boundary. Keep remote work outside the socket's immediate synchronous response path.

## Remaining verification

| Gap | Required evidence before release |
| --- | --- |
| Data licences | Written clearance for bundled snapshots, app-level redistribution and workplace use. PhishTank current terms and key availability need particular care |
| VirusTotal lookup sharing | Explicit answer about read-only hash lookups, partner forwarding, retention and protection-product eligibility |
| Provider contracts | Premium VirusTotal, paid abuse.ch, OpenPhish and Spamhaus prices; Cloudflare scanner plan cost; exact allowed desktop use |
| Google | Current project quotas, key restrictions, v5 raw-URL alpha status, relay access/cost, and required warning wording |
| Privacy | Retention and sharing for lookup logs where not stated. Do not equate a lookup with a public submission without evidence |
| Runtime | Swift canonicalization against provider fixtures, stale-list handling, false positives, race cancellation, preview suppression and all opening paths |
| Performance | Local snapshot size, memory, cold start and picker latency. Network timing from the user's region. None was measured here |

## Ranked recommendation

| Rank | Move | Reason | Release condition |
| --- | --- | --- | --- |
| 1 | Local reputation interface, user-file import, shared opening policy and strict offline mode | Fits Junction's privacy promise. Reuses risk chips and block notices. Adds no mandatory provider account | Cover every opening path. Keep unknown distinct from safe. Disable existing network features in strict mode |
| 2 | Opt-in URLhaus exact-URL exports; add a phishing feed after licence clearance | Useful local malware coverage; phishing needs a separate source | Per-user eligible access or redistribution agreement. Consider OpenPhish with permission; PhishTank remains conditional on Cisco terms and access |
| 3 | Optional Google Safe Browsing v5 local-list provider for qualifying non-commercial use | Broad coverage with limited URL disclosure | User key, valid confirmation/cache rules, attribution and network consent. No claim of fully offline protection |
| 4 | Optional Web Risk provider for commercial users | Published commercial service and clear usage pricing | User project/key and budget cap. Prefer Update for URL privacy only when its much higher confirmation price is acceptable |
| 5 | Filtering DNS guidance; retain WebKit fraud warnings | Adds protection at the browser/network layer with little router-specific code | Clear scope. No automatic system DNS change and no claimed preflight Apple verdict |
| 6 | ThreatFox typed indicators and licensed Spamhaus DBL | Adds domain and infrastructure context | Confidence and scope filters, valid terms, resolver error handling. Avoid blanket shared-host blocking |
| 7 | Manual VirusTotal report lookup | Useful expert evidence | Vendor-approved use and a user key. No automatic submission or detection-product assumption |
| 8 | Manual urlscan or Cloudflare investigation | Useful page behavior evidence; poor fit for routine link routing | Explicit full-URL disclosure and visibility choice. No public fallback, no picker dependency |
