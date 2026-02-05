#!/usr/bin/env python3
"""
Momento Growth Strategy Simulation
Based on: 2026-02-01-post-reveal-monetisation-design.md

Models the viral growth loop:
Host creates → Event → Reveal → Upgrade → Web Album → Non-app viewers → App installs → New hosts

Usage:
    python growth_simulation.py
    python growth_simulation.py --months 24 --initial-hosts 100
"""

import argparse
from dataclasses import dataclass, field
from typing import List
import math


@dataclass
class SimulationConfig:
    """Configuration parameters for the growth simulation."""

    # Starting conditions
    initial_hosts: int = 50  # Seed users at launch

    # Event creation behavior
    events_per_host_per_month: float = 0.8  # Active hosts create ~1 event/month
    avg_attendees_per_event: int = 8  # Average group size
    attendees_already_have_app: float = 0.3  # % of attendees who already have the app

    # Conversion rates
    post_reveal_upgrade_rate: float = 0.25  # 25% of hosts upgrade after reveal

    # Web album growth loop
    web_album_share_rate: float = 0.7  # 70% of premium hosts share web album
    non_app_viewers_per_share: int = 5  # Non-app users who view shared album
    web_viewer_download_rate: float = 0.4  # 40% of web viewers download a photo
    download_to_install_rate: float = 0.15  # 15% of downloaders install app
    new_install_becomes_host_rate: float = 0.3  # 30% of new installs become hosts

    # Retention
    host_monthly_retention: float = 0.85  # 85% of hosts remain active each month

    # Pricing
    premium_price_gbp: float = 7.99


@dataclass
class MonthlyMetrics:
    """Metrics for a single month of the simulation."""
    month: int

    # User counts
    total_hosts: int = 0
    active_hosts: int = 0
    total_app_users: int = 0

    # Activity
    events_created: int = 0
    total_attendees: int = 0
    new_app_installs_from_events: int = 0

    # Monetization
    premium_upgrades: int = 0
    revenue_gbp: float = 0.0
    cumulative_revenue_gbp: float = 0.0

    # Growth loop
    web_albums_shared: int = 0
    web_album_views: int = 0
    web_downloads: int = 0
    installs_from_web: int = 0
    new_hosts_from_web: int = 0

    # Derived metrics
    conversion_rate: float = 0.0
    viral_coefficient: float = 0.0


def run_simulation(config: SimulationConfig, months: int = 12) -> List[MonthlyMetrics]:
    """Run the growth simulation for the specified number of months."""

    results: List[MonthlyMetrics] = []

    # Initialize
    total_hosts = config.initial_hosts
    active_hosts = config.initial_hosts
    total_app_users = config.initial_hosts
    cumulative_revenue = 0.0

    for month in range(1, months + 1):
        metrics = MonthlyMetrics(month=month)

        # --- Event Creation ---
        events_created = int(active_hosts * config.events_per_host_per_month)
        total_attendees = events_created * config.avg_attendees_per_event

        # New app users from events (attendees who didn't have app)
        new_attendees_without_app = int(
            total_attendees * (1 - config.attendees_already_have_app)
        )
        # Not all will install, assume 60% of invited non-app attendees install
        new_installs_from_events = int(new_attendees_without_app * 0.6)

        # --- Monetization (Post-Reveal Conversion) ---
        premium_upgrades = int(events_created * config.post_reveal_upgrade_rate)
        revenue = premium_upgrades * config.premium_price_gbp
        cumulative_revenue += revenue

        # --- Web Album Growth Loop ---
        # Premium hosts who share their web album
        web_albums_shared = int(premium_upgrades * config.web_album_share_rate)

        # Non-app users who view shared albums
        web_album_views = web_albums_shared * config.non_app_viewers_per_share

        # Downloads from web viewers
        web_downloads = int(web_album_views * config.web_viewer_download_rate)

        # App installs from web (after seeing CTA on download)
        installs_from_web = int(web_downloads * config.download_to_install_rate)

        # New hosts created from web installs
        new_hosts_from_web = int(installs_from_web * config.new_install_becomes_host_rate)

        # --- Update Totals ---
        # Some existing hosts churn
        active_hosts = int(active_hosts * config.host_monthly_retention)

        # Add new hosts (from web loop + some % of new event installs become hosts)
        new_hosts_from_events = int(new_installs_from_events * 0.2)
        new_hosts = new_hosts_from_web + new_hosts_from_events

        total_hosts += new_hosts
        active_hosts += new_hosts
        total_app_users += new_installs_from_events + installs_from_web

        # --- Calculate Derived Metrics ---
        conversion_rate = premium_upgrades / events_created if events_created > 0 else 0

        # Viral coefficient: new hosts generated per existing active host
        viral_coefficient = new_hosts / (active_hosts - new_hosts) if (active_hosts - new_hosts) > 0 else 0

        # --- Record Metrics ---
        metrics.total_hosts = total_hosts
        metrics.active_hosts = active_hosts
        metrics.total_app_users = total_app_users
        metrics.events_created = events_created
        metrics.total_attendees = total_attendees
        metrics.new_app_installs_from_events = new_installs_from_events
        metrics.premium_upgrades = premium_upgrades
        metrics.revenue_gbp = revenue
        metrics.cumulative_revenue_gbp = cumulative_revenue
        metrics.web_albums_shared = web_albums_shared
        metrics.web_album_views = web_album_views
        metrics.web_downloads = web_downloads
        metrics.installs_from_web = installs_from_web
        metrics.new_hosts_from_web = new_hosts_from_web
        metrics.conversion_rate = conversion_rate
        metrics.viral_coefficient = viral_coefficient

        results.append(metrics)

    return results


def print_results(results: List[MonthlyMetrics], config: SimulationConfig):
    """Print simulation results in a readable format."""

    print("\n" + "=" * 80)
    print("MOMENTO GROWTH SIMULATION")
    print("=" * 80)
    print(f"\nConfiguration:")
    print(f"  Initial hosts: {config.initial_hosts}")
    print(f"  Events per host/month: {config.events_per_host_per_month}")
    print(f"  Avg attendees: {config.avg_attendees_per_event}")
    print(f"  Post-reveal upgrade rate: {config.post_reveal_upgrade_rate:.0%}")
    print(f"  Premium price: £{config.premium_price_gbp}")

    print("\n" + "-" * 80)
    print(f"{'Month':>5} | {'Active':>7} | {'Events':>6} | {'Upgrades':>8} | {'Revenue':>10} | {'Cumul Rev':>10} | {'Web→App':>7} | {'New Hosts':>9}")
    print(f"{'':>5} | {'Hosts':>7} | {'':>6} | {'':>8} | {'(£)':>10} | {'(£)':>10} | {'Installs':>7} | {'(from web)':>9}")
    print("-" * 80)

    for m in results:
        print(f"{m.month:>5} | {m.active_hosts:>7,} | {m.events_created:>6,} | {m.premium_upgrades:>8,} | {m.revenue_gbp:>10,.0f} | {m.cumulative_revenue_gbp:>10,.0f} | {m.installs_from_web:>7,} | {m.new_hosts_from_web:>9,}")

    # Summary
    final = results[-1]
    print("-" * 80)
    print(f"\nAfter {len(results)} months:")
    print(f"  Total app users: {final.total_app_users:,}")
    print(f"  Active hosts: {final.active_hosts:,}")
    print(f"  Cumulative revenue: £{final.cumulative_revenue_gbp:,.0f}")
    print(f"  Total premium upgrades: {sum(m.premium_upgrades for m in results):,}")
    print(f"  Total events created: {sum(m.events_created for m in results):,}")

    # Growth loop effectiveness
    total_web_installs = sum(m.installs_from_web for m in results)
    total_new_hosts_from_web = sum(m.new_hosts_from_web for m in results)
    print(f"\nGrowth loop effectiveness:")
    print(f"  App installs from web albums: {total_web_installs:,}")
    print(f"  New hosts from web loop: {total_new_hosts_from_web:,}")
    print(f"  Final viral coefficient: {final.viral_coefficient:.3f}")


def print_scenario_comparison(scenarios: dict):
    """Print comparison of different scenarios."""

    print("\n" + "=" * 80)
    print("SCENARIO COMPARISON (12 months)")
    print("=" * 80)

    print(f"\n{'Scenario':<25} | {'Active Hosts':>12} | {'App Users':>10} | {'Revenue':>12} | {'Viral Coef':>10}")
    print("-" * 80)

    for name, results in scenarios.items():
        final = results[-1]
        print(f"{name:<25} | {final.active_hosts:>12,} | {final.total_app_users:>10,} | £{final.cumulative_revenue_gbp:>10,.0f} | {final.viral_coefficient:>10.3f}")


def run_scenarios():
    """Run multiple scenarios with different assumptions."""

    scenarios = {}

    # Base case
    base_config = SimulationConfig()
    scenarios["Base Case"] = run_simulation(base_config, months=12)

    # Conservative (lower conversion, lower virality)
    conservative = SimulationConfig(
        post_reveal_upgrade_rate=0.15,  # 15% upgrade
        web_album_share_rate=0.5,  # 50% share
        download_to_install_rate=0.10,  # 10% install from web
        new_install_becomes_host_rate=0.2,  # 20% become hosts
    )
    scenarios["Conservative"] = run_simulation(conservative, months=12)

    # Optimistic (higher conversion, better virality)
    optimistic = SimulationConfig(
        post_reveal_upgrade_rate=0.35,  # 35% upgrade
        web_album_share_rate=0.85,  # 85% share
        download_to_install_rate=0.20,  # 20% install from web
        new_install_becomes_host_rate=0.4,  # 40% become hosts
        avg_attendees_per_event=12,  # Larger groups
    )
    scenarios["Optimistic"] = run_simulation(optimistic, months=12)

    # Higher initial seed
    higher_seed = SimulationConfig(initial_hosts=200)
    scenarios["200 Initial Hosts"] = run_simulation(higher_seed, months=12)

    # Lower price sensitivity test (if £4.99 → 40% conversion)
    lower_price = SimulationConfig(
        premium_price_gbp=4.99,
        post_reveal_upgrade_rate=0.40,  # Higher conversion at lower price
    )
    scenarios["£4.99 @ 40% conv"] = run_simulation(lower_price, months=12)

    # Higher price test (if £12.99 → 15% conversion)
    higher_price = SimulationConfig(
        premium_price_gbp=12.99,
        post_reveal_upgrade_rate=0.15,  # Lower conversion at higher price
    )
    scenarios["£12.99 @ 15% conv"] = run_simulation(higher_price, months=12)

    return scenarios


def calculate_ltv_and_cac_ceiling(config: SimulationConfig) -> dict:
    """Calculate LTV and maximum allowable CAC."""

    # Average revenue per host
    # Assume a host creates events over ~6 months on average
    avg_events_per_host_lifetime = config.events_per_host_per_month * 6
    avg_upgrades_per_host = avg_events_per_host_lifetime * config.post_reveal_upgrade_rate
    ltv = avg_upgrades_per_host * config.premium_price_gbp

    # Viral value: each host brings in more hosts through web loop
    # Simplified: assume viral coefficient of 0.1 means each host brings 0.1 new hosts
    # With their LTV, this adds value
    viral_multiplier = 1 / (1 - 0.1)  # Geometric series for k=0.1
    adjusted_ltv = ltv * viral_multiplier

    # CAC ceiling (assuming 3:1 LTV:CAC ratio for sustainable growth)
    cac_ceiling = adjusted_ltv / 3

    return {
        "ltv_direct": ltv,
        "viral_multiplier": viral_multiplier,
        "ltv_with_virality": adjusted_ltv,
        "cac_ceiling_3to1": cac_ceiling,
    }


def print_unit_economics(config: SimulationConfig):
    """Print unit economics analysis."""

    economics = calculate_ltv_and_cac_ceiling(config)

    print("\n" + "=" * 80)
    print("UNIT ECONOMICS")
    print("=" * 80)

    print(f"\nAssumptions:")
    print(f"  Events per host/month: {config.events_per_host_per_month}")
    print(f"  Average host lifetime: 6 months")
    print(f"  Upgrade rate: {config.post_reveal_upgrade_rate:.0%}")
    print(f"  Premium price: £{config.premium_price_gbp}")

    print(f"\nCalculations:")
    print(f"  Average events per host lifetime: {config.events_per_host_per_month * 6:.1f}")
    print(f"  Average upgrades per host: {config.events_per_host_per_month * 6 * config.post_reveal_upgrade_rate:.2f}")
    print(f"  Direct LTV: £{economics['ltv_direct']:.2f}")
    print(f"  Viral multiplier: {economics['viral_multiplier']:.2f}x")
    print(f"  LTV with virality: £{economics['ltv_with_virality']:.2f}")
    print(f"  Max CAC (3:1 ratio): £{economics['cac_ceiling_3to1']:.2f}")


def print_growth_loop_breakdown(config: SimulationConfig):
    """Print detailed breakdown of the growth loop funnel."""

    print("\n" + "=" * 80)
    print("GROWTH LOOP FUNNEL (per 100 events)")
    print("=" * 80)

    events = 100

    # Step through the funnel
    upgrades = events * config.post_reveal_upgrade_rate
    shared = upgrades * config.web_album_share_rate
    views = shared * config.non_app_viewers_per_share
    downloads = views * config.web_viewer_download_rate
    installs = downloads * config.download_to_install_rate
    new_hosts = installs * config.new_install_becomes_host_rate

    print(f"\n  100 events created")
    print(f"    ↓ {config.post_reveal_upgrade_rate:.0%} upgrade")
    print(f"  {upgrades:.0f} premium upgrades (£{upgrades * config.premium_price_gbp:.0f} revenue)")
    print(f"    ↓ {config.web_album_share_rate:.0%} share web album")
    print(f"  {shared:.0f} web albums shared")
    print(f"    ↓ {config.non_app_viewers_per_share} non-app viewers each")
    print(f"  {views:.0f} web album views")
    print(f"    ↓ {config.web_viewer_download_rate:.0%} download a photo")
    print(f"  {downloads:.0f} downloads (see CTA)")
    print(f"    ↓ {config.download_to_install_rate:.0%} install app")
    print(f"  {installs:.0f} app installs from web")
    print(f"    ↓ {config.new_install_becomes_host_rate:.0%} become hosts")
    print(f"  {new_hosts:.1f} new hosts")

    # Calculate viral coefficient
    # How many new hosts does each event generate?
    new_hosts_per_event = new_hosts / events
    # If each host creates 0.8 events/month, how many new hosts per host?
    viral_k = new_hosts_per_event * config.events_per_host_per_month

    print(f"\n  Viral coefficient (k): {viral_k:.3f}")
    print(f"  (k > 1 = exponential growth, k < 1 = needs paid acquisition)")

    if viral_k >= 1:
        print(f"  ✓ Self-sustaining growth!")
    else:
        deficit_per_host = 1 - viral_k
        print(f"  Each host generates {viral_k:.2f} new hosts")
        print(f"  Need paid acquisition to fill {deficit_per_host:.2f} gap per host")


def main():
    parser = argparse.ArgumentParser(description="Momento Growth Strategy Simulation")
    parser.add_argument("--months", type=int, default=12, help="Number of months to simulate")
    parser.add_argument("--initial-hosts", type=int, default=50, help="Initial number of hosts")
    parser.add_argument("--scenarios", action="store_true", help="Run multiple scenarios")
    args = parser.parse_args()

    config = SimulationConfig(initial_hosts=args.initial_hosts)

    # Print growth loop breakdown
    print_growth_loop_breakdown(config)

    # Print unit economics
    print_unit_economics(config)

    # Run base simulation
    results = run_simulation(config, months=args.months)
    print_results(results, config)

    # Run scenarios if requested
    if args.scenarios:
        scenarios = run_scenarios()
        print_scenario_comparison(scenarios)

    print("\n" + "=" * 80)
    print("KEY INSIGHTS")
    print("=" * 80)
    print("""
1. POST-REVEAL CONVERSION is the most critical lever
   - Direct impact on revenue
   - Funds the growth loop (premium → web album → new users)

2. WEB ALBUM SHARING is the viral multiplier
   - Premium upgrade creates distribution opportunity
   - Higher share rate = faster growth

3. DOWNLOAD CTA CONVERSION is the growth loop bottleneck
   - This is where non-app users become users
   - Optimize this aggressively

4. NEW HOST CREATION completes the loop
   - Not everyone needs to become a host
   - But each new host creates many events

5. PRICE SENSITIVITY matters
   - Lower price may yield more revenue via higher conversion
   - Test £4.99 vs £7.99 vs £9.99 with real users
""")


if __name__ == "__main__":
    main()
