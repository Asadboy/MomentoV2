#!/usr/bin/env python3
"""
Momento Go-To-Market Simulation
Models the actual GTM strategy:

Phase 1: Seed with friends (~50 users)
Phase 2: Hijack B2B test (rave company partnership)
Phase 3: Organic TikTok/UGC
Phase 4: Festival partnership (end of summer)

Usage:
    python gtm_simulation.py
    python gtm_simulation.py --hijack-size 400
"""

import argparse
from dataclasses import dataclass
from typing import List, Optional


@dataclass
class MonthData:
    """Data for a single month."""
    month: int
    phase: str

    # Inputs for this month
    new_users_from_seed: int = 0
    new_users_from_b2b: int = 0
    new_users_from_tiktok: int = 0
    new_users_from_festival: int = 0

    # Calculated
    total_users: int = 0
    active_users: int = 0
    events_created: int = 0
    premium_upgrades: int = 0
    revenue: float = 0.0
    cumulative_revenue: float = 0.0

    # Web album loop
    web_album_views: int = 0
    installs_from_web: int = 0


@dataclass
class GTMConfig:
    """Configuration for the GTM simulation."""

    # Phase 1: Seed (your friend group)
    seed_users: int = 50
    seed_events_per_user_per_month: float = 1.2  # Friends are engaged, create more events
    seed_avg_group_size: int = 8
    seed_upgrade_rate: float = 0.35  # Friends more likely to support/upgrade

    # Phase 2: Hijack B2B
    hijack_attendees_per_rave: int = 400
    hijack_raves_per_month: int = 2  # How often do they run events?
    hijack_app_install_rate: float = 0.25  # % of attendees who install app
    hijack_upgrade_rate: float = 0.0  # B2B = free for attendees, Hijack pays or free trial
    hijack_becomes_host_rate: float = 0.05  # % who later create their own events
    hijack_monthly_fee: float = 0.0  # Could charge Hijack, or do it free for exposure

    # Phase 3: TikTok/UGC
    tiktok_monthly_installs_low: int = 50  # Conservative: 50 installs/month
    tiktok_monthly_installs_mid: int = 200  # Mid: 200 installs/month
    tiktok_monthly_installs_high: int = 1000  # If something goes viral
    tiktok_install_to_host_rate: float = 0.15  # TikTok users who become hosts
    tiktok_upgrade_rate: float = 0.20  # Lower than friends, unknown users

    # Phase 4: Festival
    festival_attendees: int = 5000  # Small-mid festival
    festival_app_install_rate: float = 0.10  # 10% install at festival
    festival_becomes_host_rate: float = 0.03  # Lower conversion to host
    festival_fee: float = 0.0  # Probably free for first partnership

    # General parameters
    premium_price: float = 7.99
    monthly_churn_rate: float = 0.15  # 15% of users become inactive each month
    events_per_host_per_month: float = 0.6  # General user (not seed)
    avg_group_size: int = 6
    general_upgrade_rate: float = 0.25

    # Web album loop (applies to all)
    web_share_rate: float = 0.70
    web_viewers_per_share: int = 5
    web_download_rate: float = 0.40
    web_download_to_install: float = 0.15
    web_install_to_host: float = 0.25


def run_gtm_simulation(config: GTMConfig, months: int = 12, tiktok_scenario: str = "mid") -> List[MonthData]:
    """Run the GTM simulation with phased growth."""

    results = []

    # Track user pools separately
    seed_users = 0
    b2b_users = 0
    tiktok_users = 0
    festival_users = 0
    web_loop_users = 0

    # Track hosts (users who create events)
    seed_hosts = 0
    organic_hosts = 0  # From B2B, TikTok, festival, web loop

    cumulative_revenue = 0.0

    # TikTok install rate based on scenario
    tiktok_installs = {
        "low": config.tiktok_monthly_installs_low,
        "mid": config.tiktok_monthly_installs_mid,
        "high": config.tiktok_monthly_installs_high,
    }[tiktok_scenario]

    for month in range(1, months + 1):
        data = MonthData(month=month, phase="")

        # Determine phase and inputs
        if month <= 2:
            # Phase 1: Seed
            data.phase = "Seed (Friends)"
            if month == 1:
                data.new_users_from_seed = config.seed_users
                seed_users = config.seed_users
                seed_hosts = config.seed_users  # All seed users are potential hosts

        elif month <= 4:
            # Phase 2: Hijack B2B test
            data.phase = "Hijack B2B"
            rave_installs = int(config.hijack_attendees_per_rave * config.hijack_raves_per_month * config.hijack_app_install_rate)
            data.new_users_from_b2b = rave_installs
            b2b_users += rave_installs
            # Some become hosts
            new_hosts_from_b2b = int(rave_installs * config.hijack_becomes_host_rate)
            organic_hosts += new_hosts_from_b2b

        elif month <= 6:
            # Phase 3: TikTok/UGC ramp
            data.phase = "TikTok/UGC"
            # Ramp up TikTok (starts slower, builds)
            ramp_factor = 0.5 if month == 5 else 1.0
            monthly_tiktok = int(tiktok_installs * ramp_factor)
            data.new_users_from_tiktok = monthly_tiktok
            tiktok_users += monthly_tiktok
            # Some become hosts
            new_hosts_from_tiktok = int(monthly_tiktok * config.tiktok_install_to_host_rate)
            organic_hosts += new_hosts_from_tiktok

        else:
            # Phase 4: Festival + continued TikTok
            data.phase = "Festival + TikTok"

            # Continued TikTok
            data.new_users_from_tiktok = tiktok_installs
            tiktok_users += tiktok_installs
            new_hosts_from_tiktok = int(tiktok_installs * config.tiktok_install_to_host_rate)
            organic_hosts += new_hosts_from_tiktok

            # Festival (one-time in month 7, end of summer)
            if month == 7:
                festival_installs = int(config.festival_attendees * config.festival_app_install_rate)
                data.new_users_from_festival = festival_installs
                festival_users += festival_installs
                new_hosts_from_festival = int(festival_installs * config.festival_becomes_host_rate)
                organic_hosts += new_hosts_from_festival

        # Also continue B2B after initial test if successful
        if month > 4:
            # Assume Hijack continues + maybe another partner
            partners = 1 if month <= 6 else 2
            rave_installs = int(config.hijack_attendees_per_rave * config.hijack_raves_per_month * config.hijack_app_install_rate * partners)
            data.new_users_from_b2b = rave_installs
            b2b_users += rave_installs
            new_hosts_from_b2b = int(rave_installs * config.hijack_becomes_host_rate)
            organic_hosts += new_hosts_from_b2b

        # Apply churn
        seed_hosts = int(seed_hosts * (1 - config.monthly_churn_rate * 0.5))  # Lower churn for friends
        organic_hosts = int(organic_hosts * (1 - config.monthly_churn_rate))

        # Calculate events created
        seed_events = int(seed_hosts * config.seed_events_per_user_per_month)
        organic_events = int(organic_hosts * config.events_per_host_per_month)
        total_events = seed_events + organic_events
        data.events_created = total_events

        # Calculate upgrades and revenue
        seed_upgrades = int(seed_events * config.seed_upgrade_rate)
        organic_upgrades = int(organic_events * config.general_upgrade_rate)
        total_upgrades = seed_upgrades + organic_upgrades
        data.premium_upgrades = total_upgrades

        revenue = total_upgrades * config.premium_price
        data.revenue = revenue
        cumulative_revenue += revenue
        data.cumulative_revenue = cumulative_revenue

        # Web album loop
        web_albums_shared = int(total_upgrades * config.web_share_rate)
        web_views = web_albums_shared * config.web_viewers_per_share
        web_downloads = int(web_views * config.web_download_rate)
        web_installs = int(web_downloads * config.web_download_to_install)
        web_new_hosts = int(web_installs * config.web_install_to_host)

        data.web_album_views = web_views
        data.installs_from_web = web_installs
        web_loop_users += web_installs
        organic_hosts += web_new_hosts

        # Total users and active
        total_users = seed_users + b2b_users + tiktok_users + festival_users + web_loop_users
        active_users = seed_hosts + organic_hosts + int((total_users - seed_hosts - organic_hosts) * 0.3)  # Non-hosts less active

        data.total_users = total_users
        data.active_users = active_users

        results.append(data)

    return results


def print_gtm_results(results: List[MonthData], config: GTMConfig, scenario: str):
    """Print GTM simulation results."""

    print("\n" + "=" * 90)
    print(f"MOMENTO GTM SIMULATION - {scenario.upper()} TIKTOK SCENARIO")
    print("=" * 90)

    print(f"\nConfiguration:")
    print(f"  Seed users: {config.seed_users}")
    print(f"  Hijack rave size: {config.hijack_attendees_per_rave} attendees")
    print(f"  TikTok installs/month: {scenario}")
    print(f"  Festival size: {config.festival_attendees} attendees")
    print(f"  Premium price: £{config.premium_price}")

    print("\n" + "-" * 90)
    print(f"{'Month':>5} | {'Phase':<20} | {'Users':>7} | {'Events':>6} | {'Upgrades':>8} | {'Revenue':>8} | {'Cumul':>10}")
    print("-" * 90)

    for m in results:
        print(f"{m.month:>5} | {m.phase:<20} | {m.total_users:>7,} | {m.events_created:>6,} | {m.premium_upgrades:>8,} | £{m.revenue:>7,.0f} | £{m.cumulative_revenue:>9,.0f}")

    final = results[-1]
    print("-" * 90)

    print(f"\nAfter {len(results)} months:")
    print(f"  Total users: {final.total_users:,}")
    print(f"  Total events: {sum(m.events_created for m in results):,}")
    print(f"  Total upgrades: {sum(m.premium_upgrades for m in results):,}")
    print(f"  Total revenue: £{final.cumulative_revenue:,.0f}")

    # User acquisition breakdown
    total_seed = results[0].new_users_from_seed
    total_b2b = sum(m.new_users_from_b2b for m in results)
    total_tiktok = sum(m.new_users_from_tiktok for m in results)
    total_festival = sum(m.new_users_from_festival for m in results)
    total_web = sum(m.installs_from_web for m in results)

    print(f"\nUser acquisition by channel:")
    print(f"  Seed (friends): {total_seed:,}")
    print(f"  B2B (Hijack+): {total_b2b:,}")
    print(f"  TikTok/UGC: {total_tiktok:,}")
    print(f"  Festival: {total_festival:,}")
    print(f"  Web album loop: {total_web:,}")


def print_scenario_comparison(config: GTMConfig, months: int = 12):
    """Compare different TikTok scenarios."""

    scenarios = {}
    for scenario in ["low", "mid", "high"]:
        scenarios[scenario] = run_gtm_simulation(config, months, scenario)

    print("\n" + "=" * 90)
    print("SCENARIO COMPARISON")
    print("=" * 90)

    print(f"\n{'TikTok Scenario':<20} | {'Total Users':>12} | {'Total Revenue':>14} | {'Events':>10} | {'Upgrades':>10}")
    print("-" * 90)

    for name, results in scenarios.items():
        final = results[-1]
        total_events = sum(m.events_created for m in results)
        total_upgrades = sum(m.premium_upgrades for m in results)
        label = {
            "low": f"Low ({config.tiktok_monthly_installs_low}/mo)",
            "mid": f"Mid ({config.tiktok_monthly_installs_mid}/mo)",
            "high": f"High ({config.tiktok_monthly_installs_high}/mo)",
        }[name]
        print(f"{label:<20} | {final.total_users:>12,} | £{final.cumulative_revenue:>13,.0f} | {total_events:>10,} | {total_upgrades:>10,}")


def print_channel_analysis(config: GTMConfig):
    """Analyze each channel's unit economics."""

    print("\n" + "=" * 90)
    print("CHANNEL UNIT ECONOMICS")
    print("=" * 90)

    # Seed channel
    seed_ltv = config.seed_events_per_user_per_month * 6 * config.seed_upgrade_rate * config.premium_price
    print(f"\n1. SEED (Friends)")
    print(f"   Users: {config.seed_users}")
    print(f"   Events/user/month: {config.seed_events_per_user_per_month}")
    print(f"   Upgrade rate: {config.seed_upgrade_rate:.0%}")
    print(f"   LTV per user: £{seed_ltv:.2f}")
    print(f"   CAC: £0 (organic)")
    print(f"   → Best channel for learning and iteration")

    # B2B channel
    users_per_rave = config.hijack_attendees_per_rave * config.hijack_app_install_rate
    hosts_per_rave = users_per_rave * config.hijack_becomes_host_rate
    b2b_ltv_per_host = config.events_per_host_per_month * 6 * config.general_upgrade_rate * config.premium_price
    total_value_per_rave = hosts_per_rave * b2b_ltv_per_host

    print(f"\n2. B2B (Hijack)")
    print(f"   Attendees per rave: {config.hijack_attendees_per_rave}")
    print(f"   App installs per rave: {users_per_rave:.0f} ({config.hijack_app_install_rate:.0%})")
    print(f"   Become hosts: {hosts_per_rave:.0f} ({config.hijack_becomes_host_rate:.0%})")
    print(f"   LTV per host: £{b2b_ltv_per_host:.2f}")
    print(f"   Total LTV per rave: £{total_value_per_rave:.0f}")
    print(f"   → Value prop: Free UGC + custom album for Hijack")
    print(f"   → You get: Mass user acquisition + proof for festivals")

    # TikTok channel
    tiktok_hosts_per_100 = 100 * config.tiktok_install_to_host_rate
    tiktok_ltv_per_host = config.events_per_host_per_month * 6 * config.tiktok_upgrade_rate * config.premium_price
    tiktok_ltv_per_100_installs = tiktok_hosts_per_100 * tiktok_ltv_per_host

    print(f"\n3. TIKTOK/UGC")
    print(f"   Hosts per 100 installs: {tiktok_hosts_per_100:.0f}")
    print(f"   Upgrade rate: {config.tiktok_upgrade_rate:.0%}")
    print(f"   LTV per host: £{tiktok_ltv_per_host:.2f}")
    print(f"   LTV per 100 installs: £{tiktok_ltv_per_100_installs:.0f}")
    print(f"   → Highly variable, one viral video can change everything")
    print(f"   → Focus on: reveal reactions, before/after, emotional moments")

    # Festival channel
    festival_installs = config.festival_attendees * config.festival_app_install_rate
    festival_hosts = festival_installs * config.festival_becomes_host_rate
    festival_ltv = festival_hosts * b2b_ltv_per_host

    print(f"\n4. FESTIVAL")
    print(f"   Attendees: {config.festival_attendees}")
    print(f"   App installs: {festival_installs:.0f} ({config.festival_app_install_rate:.0%})")
    print(f"   Become hosts: {festival_hosts:.0f} ({config.festival_becomes_host_rate:.0%})")
    print(f"   Total LTV: £{festival_ltv:.0f}")
    print(f"   → One-time spike, good for credibility + case study")
    print(f"   → Lower host conversion (strangers, one-time event)")


def print_milestones(results: List[MonthData]):
    """Print key milestones timeline."""

    print("\n" + "=" * 90)
    print("KEY MILESTONES")
    print("=" * 90)

    milestones = [
        (100, "users"),
        (500, "users"),
        (1000, "users"),
        (5000, "users"),
        (1000, "revenue"),
        (5000, "revenue"),
        (10000, "revenue"),
    ]

    print(f"\n{'Milestone':<25} | {'Month':>6} | {'Phase':<20}")
    print("-" * 60)

    for target, metric in milestones:
        for m in results:
            value = m.total_users if metric == "users" else m.cumulative_revenue
            if value >= target:
                label = f"{target:,} {metric}" if metric == "users" else f"£{target:,} revenue"
                print(f"{label:<25} | {m.month:>6} | {m.phase:<20}")
                break
        else:
            label = f"{target:,} {metric}" if metric == "users" else f"£{target:,} revenue"
            print(f"{label:<25} | {'N/A':>6} | {'Not reached':<20}")


def print_what_if_analysis(config: GTMConfig):
    """What-if analysis for key decisions."""

    print("\n" + "=" * 90)
    print("WHAT-IF ANALYSIS")
    print("=" * 90)

    base_results = run_gtm_simulation(config, 12, "mid")
    base_revenue = base_results[-1].cumulative_revenue
    base_users = base_results[-1].total_users

    print(f"\nBase case: {base_users:,} users, £{base_revenue:,.0f} revenue")

    # What if Hijack is bigger?
    config_big_hijack = GTMConfig(**{**config.__dict__, "hijack_attendees_per_rave": 800})
    results = run_gtm_simulation(config_big_hijack, 12, "mid")
    print(f"\nIf Hijack raves are 800 people (not {config.hijack_attendees_per_rave}):")
    print(f"  → {results[-1].total_users:,} users (+{results[-1].total_users - base_users:,})")
    print(f"  → £{results[-1].cumulative_revenue:,.0f} revenue (+£{results[-1].cumulative_revenue - base_revenue:,.0f})")

    # What if TikTok goes viral?
    results = run_gtm_simulation(config, 12, "high")
    print(f"\nIf TikTok goes viral ({config.tiktok_monthly_installs_high}/month):")
    print(f"  → {results[-1].total_users:,} users (+{results[-1].total_users - base_users:,})")
    print(f"  → £{results[-1].cumulative_revenue:,.0f} revenue (+£{results[-1].cumulative_revenue - base_revenue:,.0f})")

    # What if higher upgrade rate?
    config_high_convert = GTMConfig(**{**config.__dict__, "general_upgrade_rate": 0.35})
    results = run_gtm_simulation(config_high_convert, 12, "mid")
    print(f"\nIf general upgrade rate is 35% (not 25%):")
    print(f"  → £{results[-1].cumulative_revenue:,.0f} revenue (+£{results[-1].cumulative_revenue - base_revenue:,.0f})")

    # What if festival is bigger?
    config_big_fest = GTMConfig(**{**config.__dict__, "festival_attendees": 15000})
    results = run_gtm_simulation(config_big_fest, 12, "mid")
    print(f"\nIf festival is 15,000 people (not {config.festival_attendees}):")
    print(f"  → {results[-1].total_users:,} users (+{results[-1].total_users - base_users:,})")


def main():
    parser = argparse.ArgumentParser(description="Momento GTM Simulation")
    parser.add_argument("--months", type=int, default=12, help="Months to simulate")
    parser.add_argument("--hijack-size", type=int, default=400, help="Hijack rave attendees")
    parser.add_argument("--festival-size", type=int, default=5000, help="Festival attendees")
    parser.add_argument("--tiktok", choices=["low", "mid", "high"], default="mid", help="TikTok scenario")
    args = parser.parse_args()

    config = GTMConfig(
        hijack_attendees_per_rave=args.hijack_size,
        festival_attendees=args.festival_size,
    )

    # Run main simulation
    results = run_gtm_simulation(config, args.months, args.tiktok)
    print_gtm_results(results, config, args.tiktok)

    # Channel analysis
    print_channel_analysis(config)

    # Milestones
    print_milestones(results)

    # Scenario comparison
    print_scenario_comparison(config, args.months)

    # What-if analysis
    print_what_if_analysis(config)

    print("\n" + "=" * 90)
    print("RECOMMENDATIONS")
    print("=" * 90)
    print("""
1. SEED PHASE (Month 1-2)
   - Get 50 friends using it for real events
   - Focus on: Does the reveal actually feel magical?
   - Key metric: Do hosts upgrade without being asked?

2. HIJACK TEST (Month 3-4)
   - Offer free premium experience (you eat the cost)
   - Build: Custom web album with Hijack branding
   - Key metric: Do ravers share the album link?
   - Case study = leverage for festivals

3. TIKTOK/UGC (Month 4-6)
   - Content ideas: reveal reactions, "POV: your photos finally unlock"
   - Don't need viral, steady 200/month is solid
   - Key metric: Cost per install (if boosting)

4. FESTIVAL (Month 7+)
   - Use Hijack case study to pitch
   - Offer: Free app for attendees + web album for festival social
   - Key metric: Press/social coverage value

5. OVERALL
   - B2B is your distribution hack (someone else's audience)
   - Consumer (TikTok) is gravy, not the main course
   - Revenue will be modest until you have 1000+ active hosts
""")


if __name__ == "__main__":
    main()
