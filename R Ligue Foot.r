# ===================== MULTI-LIGUES FOOTBALL EU (sans Portugal) =====================

suppressPackageStartupMessages({
  library(worldfootballR); library(dplyr); library(readr); library(lubridate)
})

# ---------- Détection automatique de la saison ----------
detect_season_end_year <- function() {
  today <- Sys.Date(); yyyy <- as.integer(format(today,"%Y")); mm <- as.integer(format(today,"%m"))
  ifelse(mm >= 7, yyyy + 1L, yyyy)
}

# ---------- Aliases Understat ----------
LEAGUE_CANDIDATES <- list(
  "Ligue 1"        = c("Ligue 1"),
  "La liga"        = c("La liga","La Liga"),
  "Bundesliga"     = c("Bundesliga"),
  "Serie A"        = c("Serie A","Serie a"),
  "Premier League" = c("Premier League","EPL","English Premier League","Premier league")
  # (Portugal retiré)
)

# ---------- Nb de matchs par journée ----------
MATCHES_PER_WEEK <- c(
  "Ligue 1" = 9, "La liga" = 10, "Bundesliga" = 9,
  "Serie A" = 10, "Premier League" = 10
  # "Liga Portugal" retiré
)

# ---------- Dictionnaires de noms officiels ----------
rename_fr <- c("Paris Saint Germain"="Paris Saint-Germain FC","Marseille"="Olympique de Marseille","Monaco"="AS Monaco FC",
  "Lille"="LOSC Lille Métropole","Lens"="Racing Club de Lens","Lyon"="Olympique Lyonnais","Rennes"="Stade Rennais FC",
  "Nice"="OGC Nice","Montpellier"="Montpellier Hérault SC","Toulouse"="Toulouse FC","Nantes"="FC Nantes",
  "Reims"="Stade de Reims","Brest"="Stade Brestois 29","Strasbourg"="RC Strasbourg Alsace","Le Havre"="Le Havre AC",
  "Metz"="FC Metz","Angers"="Angers SCO","Auxerre"="AJ Auxerre","Clermont"="Clermont Foot 63","Lorient"="FC Lorient")
rename_es <- c("Real Madrid"="Real Madrid CF","Barcelona"="FC Barcelona","Atletico Madrid"="Club Atletico de Madrid",
  "Athletic Club"="Athletic Club","Real Sociedad"="Real Sociedad de Futbol","Villarreal"="Villarreal CF",
  "Real Betis"="Real Betis Balompie","Sevilla"="Sevilla FC","Valencia"="Valencia CF","Getafe"="Getafe CF",
  "Rayo Vallecano"="Rayo Vallecano de Madrid","Osasuna"="CA Osasuna","Celta Vigo"="RC Celta de Vigo","Girona"="Girona FC",
  "Las Palmas"="UD Las Palmas","Alaves"="Deportivo Alaves","Mallorca"="RCD Mallorca","Granada"="Granada CF",
  "Leganes"="CD Leganes","Valladolid"="Real Valladolid CF","Espanyol"="RCD Espanyol de Barcelona","Cadiz"="Cadiz CF",
  "Almeria"="UD Almeria","Levante"="Levante UD","Eibar"="SD Eibar","Huesca"="SD Huesca","Elche"="Elche CF")
rename_de <- c("Bayern Munich"="FC Bayern München","Borussia Dortmund"="Borussia Dortmund","RB Leipzig"="RasenBallsport Leipzig",
  "Bayer Leverkusen"="Bayer 04 Leverkusen","Bayer 04"="Bayer 04 Leverkusen","Borussia M.Gladbach"="Borussia Mönchengladbach",
  "M'gladbach"="Borussia Mönchengladbach","Monchengladbach"="Borussia Mönchengladbach","VfL Wolfsburg"="VfL Wolfsburg",
  "Eintracht Frankfurt"="Eintracht Frankfurt","SC Freiburg"="Sport-Club Freiburg","TSG Hoffenheim"="TSG 1899 Hoffenheim",
  "VfB Stuttgart"="VfB Stuttgart","FC Augsburg"="FC Augsburg","Union Berlin"="1. FC Union Berlin",
  "1. FC Koln"="1. FC Köln","FC Koln"="1. FC Köln","1. FC Köln"="1. FC Köln","Werder Bremen"="SV Werder Bremen",
  "Mainz 05"="1. FSV Mainz 05","1. FSV Mainz 05"="1. FSV Mainz 05","VfL Bochum"="VfL Bochum 1848","VfL Bochum 1848"="VfL Bochum 1848",
  "Heidenheim"="1. FC Heidenheim 1846","1. FC Heidenheim"="1. FC Heidenheim 1846","Darmstadt"="SV Darmstadt 98")
rename_it <- c("Inter"="FC Internazionale Milano","AC Milan"="AC Milan","Juventus"="Juventus FC","Napoli"="SSC Napoli",
  "Roma"="AS Roma","Lazio"="SS Lazio","Fiorentina"="ACF Fiorentina","Atalanta"="Atalanta BC","Torino"="Torino FC",
  "Bologna"="Bologna FC 1909","Genoa"="Genoa CFC","Sampdoria"="UC Sampdoria","Udinese"="Udinese Calcio",
  "Sassuolo"="US Sassuolo Calcio","Verona"="Hellas Verona FC","Cagliari"="Cagliari Calcio","Empoli"="Empoli FC",
  "Parma"="Parma Calcio 1913","Lecce"="US Lecce","Monza"="AC Monza","Frosinone"="Frosinone Calcio","Venezia"="Venezia FC")
rename_en <- c("Manchester City"="Manchester City FC","Manchester Utd"="Manchester United FC","Manchester United"="Manchester United FC",
  "Arsenal"="Arsenal FC","Liverpool"="Liverpool FC","Chelsea"="Chelsea FC","Tottenham"="Tottenham Hotspur FC",
  "Newcastle Utd"="Newcastle United FC","Newcastle"="Newcastle United FC","Aston Villa"="Aston Villa FC",
  "West Ham"="West Ham United FC","Everton"="Everton FC","Brighton"="Brighton & Hove Albion FC","Crystal Palace"="Crystal Palace FC",
  "Brentford"="Brentford FC","Fulham"="Fulham FC","Wolves"="Wolverhampton Wanderers FC","Nottingham Forest"="Nottingham Forest FC",
  "Leicester"="Leicester City FC","Leeds"="Leeds United FC","Southampton"="Southampton FC","Bournemouth"="AFC Bournemouth",
  "Sheffield Utd"="Sheffield United FC","Burnley"="Burnley FC","Ipswich"="Ipswich Town FC")

# ---------- Fonction Understat ----------
one_league_table_understat <- function(league, season_end_year, renamer, matches_per_week, prefix) {
  candidates <- LEAGUE_CANDIDATES[[league]]; if (is.null(candidates)) candidates <- league
  df <- NULL; used <- NA_character_
  for (cand in candidates) {
    tmp <- try(understat_league_match_results(league = cand, season = season_end_year), silent = TRUE)
    if (!inherits(tmp,"try-error") && is.data.frame(tmp) && nrow(tmp) > 0) { df <- tmp; used <- cand; break }
  }
  if (is.null(df)) { warning("Understat vide pour ", league); return(NULL) }
  message("✔ ", league, " (Understat) alias: ", used, " (", nrow(df), " lignes)")

  date_cols <- intersect(names(df), c("date","datetime","utc_date","utcTime","kickoff","kickoff_time","start_time","match_date","match_time","time"))
  dv <- if (length(date_cols)) df[[date_cols[1]]] else seq_len(nrow(df))
  dc <- suppressWarnings(lubridate::ymd_hms(dv, quiet=TRUE))
  if (all(is.na(dc))) dc <- suppressWarnings(lubridate::ymd(dv, quiet=TRUE))
  if (all(is.na(dc))) dc <- suppressWarnings(lubridate::dmy(dv, quiet=TRUE))
  if (all(is.na(dc))) dc <- seq_len(nrow(df))

  df %>%
    mutate(.date_clean = dc) %>%
    filter(!is.na(home_goals), !is.na(away_goals)) %>%
    arrange(.date_clean, home_team, away_team) %>%
    mutate(
      Row = row_number(),
      Journee = ceiling(Row / matches_per_week),
      home_team = recode(home_team, !!!renamer),
      away_team = recode(away_team, !!!renamer)
    ) %>%
    transmute(
      Row,
      !!paste0(prefix,"_Journee") := as.integer(Journee),
      !!paste0(prefix,"_Domicile") := home_team,
      !!paste0(prefix,"_ScoreDom") := as.integer(home_goals),
      !!paste0(prefix,"_ScoreExt") := as.integer(away_goals),
      !!paste0(prefix,"_Exterieur") := away_team
    )
}

# ---------- Fonction principale (Portugal retiré) ----------
build_multi_league_table <- function(season_end_year = detect_season_end_year(),
                                     output_dir = "output") {
  season_tag <- paste0(season_end_year - 1, "_", season_end_year)

  L1  <- one_league_table_understat("Ligue 1",        season_end_year, rename_fr, MATCHES_PER_WEEK[["Ligue 1"]],        "Ligue1")
  LL  <- one_league_table_understat("La liga",        season_end_year, rename_es, MATCHES_PER_WEEK[["La liga"]],        "LaLiga")
  BUN <- one_league_table_understat("Bundesliga",     season_end_year, rename_de, MATCHES_PER_WEEK[["Bundesliga"]],     "Bundesliga")
  SA  <- one_league_table_understat("Serie A",        season_end_year, rename_it, MATCHES_PER_WEEK[["Serie A"]],        "SerieA")
  PL  <- one_league_table_understat("Premier League", season_end_year, rename_en, MATCHES_PER_WEEK[["Premier League"]], "PremierLeague")
  # POR retiré

  present <- Filter(Negate(is.null), list(Ligue1=L1, LaLiga=LL, Bundesliga=BUN, SerieA=SA, PremierLeague=PL))
  if (!length(present)) stop("Aucune ligue récupérée.")

  max_rows <- max(sapply(present, nrow))
  merged <- data.frame(Row = 1:max_rows)
  for (nm in names(present)) merged <- merged %>% left_join(present[[nm]], by = "Row")
  merged <- merged %>% select(-Row)

  # === EXPORT EN .XLSX ===
  library(openxlsx)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  out_file <- file.path(output_dir, paste0("Ligues Football EU ", season_tag, ".xlsx"))
  wb <- createWorkbook()
  addWorksheet(wb, "Résultats")
  writeData(wb, sheet = "Résultats", merged)
  setColWidths(wb, sheet = "Résultats", cols = 1:ncol(merged), widths = "auto")
  saveWorkbook(wb, out_file, overwrite = TRUE)
  message("✅ Exporté en Excel : ", out_file)
  merged
}

# ---------- APPEL FINAL ----------
res <- build_multi_league_table()   # ▶ Lance tout et exporte le XLSX

# (Optionnel pour éviter l'erreur XQuartz en batch non-interactif)
if (interactive()) {
  try(View(res), silent = TRUE)
}
# =====================================================================
