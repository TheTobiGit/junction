import Foundation

struct RuleRecipe: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let rules: [DomainRule]
}

enum RuleRecipes {
    static let all: [RuleRecipe] = [
        RuleRecipe(
            id: "privacy",
            name: "Privacy essentials",
            detail: "Strips trackers via the URL pipeline and sends common trackers/analytics hosts to Safari instead of Chrome.",
            rules: [
                DomainRule(host: .suffix("doubleclick.net"), action: .ask),
                DomainRule(host: .suffix("googleadservices.com"), action: .ask),
                DomainRule(host: .suffix("facebook.com"), action: .ask),
            ]
        ),
        RuleRecipe(
            id: "developer",
            name: "Developer starter",
            detail: "Sends common dev destinations (GitHub, Linear, Stripe, Figma) through the picker so you can assign them to the right profile.",
            rules: [
                DomainRule(host: .suffix("github.com"), action: .ask),
                DomainRule(host: .suffix("gitlab.com"), action: .ask),
                DomainRule(host: .suffix("linear.app"), action: .ask),
                DomainRule(host: .suffix("stripe.com"), action: .ask),
                DomainRule(host: .suffix("figma.com"), action: .ask),
                DomainRule(host: .suffix("vercel.com"), action: .ask),
                DomainRule(host: .suffix("netlify.com"), action: .ask),
            ]
        ),
        RuleRecipe(
            id: "designer",
            name: "Designer starter",
            detail: "Sends design tools through the picker so they land in the browser with your design plugins.",
            rules: [
                DomainRule(host: .suffix("figma.com"), action: .ask),
                DomainRule(host: .suffix("framer.com"), action: .ask),
                DomainRule(host: .suffix("dribbble.com"), action: .ask),
                DomainRule(host: .suffix("behance.net"), action: .ask),
            ]
        ),
        RuleRecipe(
            id: "meetings",
            name: "Meeting apps",
            detail: "Routes meeting URLs so they open in the browser where your camera and calendar are logged in.",
            rules: [
                DomainRule(host: .suffix("zoom.us"), action: .ask),
                DomainRule(host: .suffix("meet.google.com"), action: .ask),
                DomainRule(host: .suffix("teams.microsoft.com"), action: .ask),
                DomainRule(host: .suffix("whereby.com"), action: .ask),
            ]
        ),
    ]
}
