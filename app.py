"""
Mavericks vs. Rockets — Franchise History Dashboard
Runs the same SQL logic as the Snowflake project, using DuckDB on the project CSVs
so the app works anywhere (including Streamlit Community Cloud) after the trial ends.
"""
from pathlib import Path

import duckdb
import plotly.graph_objects as go
import streamlit as st

DATA = Path(__file__).parent / "data"
DAL, HOU = "Dallas Mavericks", "Houston Rockets"
COLORS = {DAL: "#0064B1", HOU: "#CE1141"}
SHORT = {DAL: "Mavericks", HOU: "Rockets"}

st.set_page_config(page_title="Mavericks vs. Rockets", page_icon="🏀", layout="wide")


# ---------------------------------------------------------------------------
# Data layer: build the same tables and view as the Snowflake script
# ---------------------------------------------------------------------------
@st.cache_resource
def get_db():
    con = duckdb.connect()
    con.execute(f"CREATE TABLE franchise_seasons AS SELECT * FROM read_csv_auto('{DATA / 'franchise_seasons.csv'}')")
    con.execute(f"CREATE TABLE head_to_head_playoffs AS SELECT * FROM read_csv_auto('{DATA / 'head_to_head_playoffs.csv'}')")
    con.execute("""
        CREATE TABLE playoff_rounds AS SELECT * FROM (VALUES
            (0,'Missed playoffs',0), (2,'Lost 1st round',1), (3,'Lost conf. semis',2),
            (4,'Lost conf. finals',3), (5,'Lost NBA Finals',4), (6,'Won NBA title',6)
        ) t(round_code, result, playoff_points)
    """)
    con.execute("""
        CREATE VIEW season_view AS
        SELECT f.*,
               CAST(f.season_end - 1 AS VARCHAR) || '-' || RIGHT(CAST(f.season_end AS VARCHAR), 2) AS season_label,
               ROUND(f.wins / (f.wins + f.losses), 3)  AS win_pct,
               CAST(FLOOR((f.season_end - 1) / 10) * 10 AS INTEGER) AS decade,
               f.round_code > 0                        AS made_playoffs,
               p.result, p.playoff_points
        FROM franchise_seasons f
        JOIN playoff_rounds p ON p.round_code = f.round_code
    """)
    return con


def run(sql: str, **params):
    return get_db().execute(sql.format(**params)).df()


def show_sql(sql: str, **params):
    with st.expander("Show the SQL"):
        st.code(sql.format(**params).strip(), language="sql")


# ---------------------------------------------------------------------------
# Queries (same logic as the Snowflake file)
# ---------------------------------------------------------------------------
SCOREBOARD = """
SELECT team,
       SUM(wins) || '-' || SUM(losses)          AS record,
       ROUND(SUM(wins) / SUM(wins + losses), 3) AS win_pct,
       COUNT_IF(made_playoffs)                  AS playoff_trips,
       COUNT_IF(round_code >= 4)                AS conf_finals,
       COUNT_IF(round_code >= 5)                AS finals_trips,
       COUNT_IF(round_code = 6)                 AS titles,
       COUNT_IF(wins >= 50)                     AS fifty_win_seasons
FROM season_view
WHERE season_end BETWEEN {start} AND {end}
GROUP BY team
ORDER BY team
"""

TUG_OF_WAR = """
SELECT d.season_end, d.season_label,
       d.win_pct AS dal_pct, h.win_pct AS hou_pct,
       d.win_pct - h.win_pct AS gap
FROM season_view d
JOIN season_view h ON h.season_end = d.season_end AND h.team = 'Houston Rockets'
WHERE d.team = 'Dallas Mavericks'
  AND d.season_end BETWEEN {start} AND {end}
ORDER BY d.season_end
"""

ROLLING = """
SELECT team, season_end,
       ROUND(SUM(wins) OVER (PARTITION BY team ORDER BY season_end ROWS BETWEEN 4 PRECEDING AND CURRENT ROW)
           / SUM(wins + losses) OVER (PARTITION BY team ORDER BY season_end ROWS BETWEEN 4 PRECEDING AND CURRENT ROW), 3)
           AS rolling_5yr_win_pct
FROM season_view
WHERE season_end >= 1981
QUALIFY season_end BETWEEN {start} AND {end}
ORDER BY season_end, team
"""

DECADES = """
SELECT decade, team,
       ROUND(SUM(wins) / SUM(wins + losses), 3) AS win_pct,
       COUNT_IF(made_playoffs)                  AS playoff_trips,
       RANK() OVER (PARTITION BY decade ORDER BY SUM(wins) / SUM(wins + losses) DESC) AS decade_rank
FROM season_view
WHERE season_end BETWEEN {start} AND {end}
GROUP BY decade, team
ORDER BY decade, team
"""

STREAKS = """
WITH flagged AS (
    SELECT team, season_end,
           season_end - ROW_NUMBER() OVER (PARTITION BY team ORDER BY season_end) AS grp
    FROM season_view
    WHERE made_playoffs AND season_end BETWEEN {start} AND {end}
)
SELECT team, MIN(season_end) AS streak_start, MAX(season_end) AS streak_end, COUNT(*) AS seasons
FROM flagged
GROUP BY team, grp
QUALIFY ROW_NUMBER() OVER (PARTITION BY team ORDER BY COUNT(*) DESC) = 1
ORDER BY team
"""

PEAKS = """
SELECT team, season_label, wins, losses, srs, result
FROM season_view
WHERE srs IS NOT NULL AND season_end BETWEEN {start} AND {end}
QUALIFY ROW_NUMBER() OVER (PARTITION BY team ORDER BY srs DESC) <= 5
ORDER BY team, srs DESC
"""

MEETINGS = """
SELECT season_end, round, winner, series
FROM head_to_head_playoffs
ORDER BY season_end
"""


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------
with st.sidebar:
    st.header("Filter")
    start, end = st.slider("Seasons ending", 1981, 2026, (1981, 2026),
                           help="1981 = the 1980-81 season, the Mavericks' first. "
                                "The comparison starts there so both teams are measured over the same years.")
    st.caption("Data: Basketball-Reference franchise histories through 2025-26. "
               "Built by Charles Esters III with SQL (DuckDB here, Snowflake in the original project).")

p = dict(start=start, end=end)
score = run(SCOREBOARD, **p).set_index("team")
tug = run(TUG_OF_WAR, **p)

dal_up = int((tug["gap"] > 0).sum())
hou_up = int((tug["gap"] < 0).sum())
leader = DAL if score.loc[DAL, "win_pct"] > score.loc[HOU, "win_pct"] else HOU

st.title("Mavericks vs. Rockets")
st.markdown(
    f"From {start - 1}-{str(start)[2:]} to {end - 1}-{str(end)[2:]}, the **{SHORT[leader]}** have the better "
    f"win percentage. Houston finished with the better record in {hou_up} of those seasons "
    f"and Dallas in {dal_up}."
)

# --- Tug of war (the signature chart) ---
st.subheader("Who had the better season, year by year")
fig = go.Figure(go.Bar(
    x=tug["season_end"], y=tug["gap"],
    marker_color=[COLORS[DAL] if g > 0 else COLORS[HOU] for g in tug["gap"]],
    customdata=tug[["season_label", "dal_pct", "hou_pct"]],
    hovertemplate="%{customdata[0]}<br>Mavericks %{customdata[1]:.3f}<br>Rockets %{customdata[2]:.3f}<extra></extra>",
))
fig.add_hline(y=0, line_color="#444", line_width=1)
fig.update_layout(
    height=380, margin=dict(l=10, r=10, t=10, b=10), showlegend=False,
    yaxis=dict(title="Win % gap", tickformat="+.2f", zeroline=False),
    xaxis=dict(title=None, dtick=5),
    annotations=[
        dict(x=0.01, y=0.98, xref="paper", yref="paper", text="Mavericks better ▲", showarrow=False,
             font=dict(color=COLORS[DAL]), xanchor="left"),
        dict(x=0.01, y=0.02, xref="paper", yref="paper", text="Rockets better ▼", showarrow=False,
             font=dict(color=COLORS[HOU]), xanchor="left"),
    ],
)
st.plotly_chart(fig, width="stretch")
show_sql(TUG_OF_WAR, **p)

# --- Scoreboard ---
st.subheader("The scoreboard")
cols = st.columns(2)
for col, team in zip(cols, [DAL, HOU]):
    r = score.loc[team]
    with col:
        st.markdown(f"<h3 style='color:{COLORS[team]};margin-bottom:0'>{team}</h3>", unsafe_allow_html=True)
        a, b, c = st.columns(3)
        a.metric("Record", r["record"])
           a.caption(f"{r['win_pct']:.3f} win percentage")
        b.metric("Playoff trips", int(r["playoff_trips"]))
        c.metric("Titles", int(r["titles"]))
        a2, b2, c2 = st.columns(3)
        a2.metric("Conf. finals", int(r["conf_finals"]))
        b2.metric("NBA Finals", int(r["finals_trips"]))
        c2.metric("50-win seasons", int(r["fifty_win_seasons"]))
show_sql(SCOREBOARD, **p)

# --- Trend and decades ---
left, right = st.columns(2)
with left:
    st.subheader("5-year rolling win %")
    roll = run(ROLLING, **p)
    fig = go.Figure()
    for team in [DAL, HOU]:
        d = roll[roll["team"] == team]
        fig.add_trace(go.Scatter(x=d["season_end"], y=d["rolling_5yr_win_pct"], name=SHORT[team],
                                 line=dict(color=COLORS[team], width=3)))
    fig.update_layout(height=360, margin=dict(l=10, r=10, t=10, b=10), yaxis=dict(tickformat=".2f"),
                      legend=dict(orientation="h", y=1.1))
    st.plotly_chart(fig, width="stretch")
    st.caption("Smooths out single seasons, but lags: a team's rebuild years stay in the average for five seasons.")
    show_sql(ROLLING, **p)

with right:
    st.subheader("Win % by decade")
    dec = run(DECADES, **p)
    fig = go.Figure()
    for team in [DAL, HOU]:
        d = dec[dec["team"] == team]
        fig.add_trace(go.Bar(x=d["decade"].astype(str) + "s", y=d["win_pct"], name=SHORT[team],
                             marker_color=COLORS[team], text=d["win_pct"].map("{:.3f}".format),
                             textposition="outside"))
    fig.update_layout(barmode="group", height=360, margin=dict(l=10, r=10, t=10, b=10),
                      yaxis=dict(range=[0, 0.8], tickformat=".2f"), legend=dict(orientation="h", y=1.1))
    st.plotly_chart(fig, width="stretch")
    st.caption("Decades are grouped by the year each season started.")
    show_sql(DECADES, **p)

# --- Details ---
st.subheader("Streaks, peaks, and playoff meetings")
a, b, c = st.columns([1, 1.4, 1])
with a:
    st.markdown("**Longest playoff streak**")
    streaks = run(STREAKS, **p)
    for _, r in streaks.iterrows():
        st.markdown(f"{SHORT[r['team']]}: **{r['seasons']} straight** ({r['streak_start']}-{r['streak_end']})")
    show_sql(STREAKS, **p)
with b:
    st.markdown("**Best seasons by SRS** (schedule-adjusted point differential)")
    st.dataframe(run(PEAKS, **p), hide_index=True, width="stretch")
    st.caption("SRS isn't available for Houston's 2019-20 to 2025-26 seasons, so those are excluded here.")
    show_sql(PEAKS, **p)
with c:
    st.markdown("**When they met in the playoffs**")
    st.dataframe(run(MEETINGS), hide_index=True, width="stretch")
    show_sql(MEETINGS)
