# report_metrics.R — program-level numbers for the Monday weekly report.
#
# Rules are copied from imslu.program.dash (9a5743c): the assessment-type
# classifier and CC dedupe (metrics_evals.R), conference rates
# (metrics_conference.R), CC quarter windows (metrics_clinic.R), verified
# duty days (metrics_duty.R) and MKSAP pace (metrics_knowledge.R). This
# email goes to all faculty and residents, so everything here is a program,
# class or PCEC-team total. The only names are the shout-outs.

# ── Assessments ────────────────────────────────────────────────────────────

# First matching item block wins.
ASSESSMENT_TYPES <- c(
  "^ass_cc_"      = "Continuity clinic",
  "^ass_obs_"     = "Observation",
  "^ass_day_"     = "Clinic day",
  "^ass_cons_"    = "Consults",
  "^ass_intern2_" = "Intern inpatient",
  "^ass_int_ip_"  = "Intern inpatient",
  "^ass_senior2_" = "Senior inpatient",
  "^ass_res_ip_"  = "Senior inpatient",
  "^ass_diamond_" = "Diamond team",
  "^ass_bridge_"  = "Bridge"
)

classify_assessments <- function(assessments) {
  type <- rep(NA_character_, nrow(assessments))
  for (pat in names(ASSESSMENT_TYPES)) {
    cols <- grep(pat, names(assessments), value = TRUE)
    if (!length(cols)) next
    filled <- rowSums(!is.na(assessments[cols]) &
                        trimws(as.matrix(assessments[cols])) != "") > 0
    type[is.na(type) & filled] <- ASSESSMENT_TYPES[[pat]]
  }
  assessments$ass_type <- dplyr::coalesce(type, "Other")
  assessments
}

# Drop exact-duplicate instances (the CC double-submission bug since
# Aug 2026); keeps the lowest instance.
dedupe_assessments <- function(assessments) {
  assessments <- dplyr::arrange(assessments, record_id, redcap_repeat_instance)
  content_cols <- setdiff(names(assessments),
                          c("redcap_repeat_instance", "assessment_complete"))
  key <- do.call(paste, c(assessments[content_cols], sep = "\u001f"))
  assessments[!duplicated(key), , drop = FALSE]
}

# Fraction of the AY elapsed at the end of the report week (pace line).
ay_fraction <- function(d) {
  as.numeric(d$week$end - d$ay_start + 1) / 365
}

# Share of residents at or above the 25-a-year pace, given per-resident AY
# counts (residents with none count as 0).
on_pace_share <- function(d, counts) {
  n <- d$roster |>
    select(record_id) |>
    left_join(counts, by = "record_id") |>
    mutate(n = coalesce(n, 0L))
  expected <- ANNUAL_TARGET * ay_fraction(d)
  list(share = mean(n$n >= expected), expected = expected, median = stats::median(n$n))
}

assessment_summary <- function(d) {
  ass <- d$assessments |>
    filter(record_id %in% d$roster$record_id,
           ass_date >= d$ay_start, ass_date <= d$week$end) |>
    dedupe_assessments() |>
    classify_assessments() |>
    mutate(ass_faculty = trimws(ass_faculty), ass_specialty = trimws(ass_specialty))
  from4 <- d$week$end - 27
  last4 <- ass |> filter(ass_date >= from4)

  list(
    week  = sum(ass$ass_date >= d$week$start),
    last4 = nrow(last4),
    ay    = nrow(ass),
    pace  = on_pace_share(d, ass |> count(record_id, name = "n")),
    by_type = ass |>
      group_by(ass_type) |>
      summarise(last4 = sum(ass_date >= from4), ay = n(), .groups = "drop") |>
      arrange(desc(ay)),
    by_service = last4 |>
      filter(!is.na(ass_specialty), ass_specialty != "") |>
      count(ass_specialty, sort = TRUE),
    top_faculty = last4 |>
      filter(!is.na(ass_faculty), ass_faculty != "") |>
      count(ass_faculty, sort = TRUE) |>
      slice_head(n = 5)
  )
}

# ── Faculty evaluations done by residents ──────────────────────────────────

faculty_eval_summary <- function(d) {
  fe <- d$faculty_evals |>
    filter(record_id %in% d$roster$record_id,
           fac_eval_date >= d$ay_start, fac_eval_date <= d$week$end)
  from4 <- d$week$end - 27
  name_of <- d$roster |> select(record_id, resident)
  list(
    week  = sum(fe$fac_eval_date >= d$week$start),
    last4 = sum(fe$fac_eval_date >= from4),
    ay    = nrow(fe),
    pace  = on_pace_share(d, fe |> count(record_id, name = "n")),
    top_residents = fe |>
      filter(fac_eval_date >= from4) |>
      count(record_id, sort = TRUE) |>
      slice_head(n = 5) |>
      left_join(name_of, by = "record_id")
  )
}

# ── Noon conference ────────────────────────────────────────────────────────

# Pooled attended / expected days, by class and program, for a window.
conf_rates <- function(d, from, to) {
  a <- d$activity |>
    filter(Date >= from, Date <= to) |>
    inner_join(d$roster |> select(record_id, class), by = "record_id")
  bind_rows(a |> mutate(class = as.character(class)),
            a |> mutate(class = "Program")) |>
    group_by(class) |>
    summarise(rate      = sum(conf_attended) / pmax(sum(conf_expected != "None"), 1),
              rate_sluh = sum(conf_attended & conf_expected == "SLUH") / pmax(sum(conf_expected == "SLUH"), 1),
              rate_va   = sum(conf_attended & conf_expected == "VA") / pmax(sum(conf_expected == "VA"), 1),
              expected  = sum(conf_expected != "None"),
              .groups = "drop") |>
    mutate(class = factor(class, levels = c("Program", CLASS_LEVELS))) |>
    arrange(class)
}

conference_summary <- function(d) {
  list(week  = conf_rates(d, d$week$start, d$week$end),
       last4 = conf_rates(d, d$week$end - 27, d$week$end),
       ay    = conf_rates(d, d$ay_start, d$week$end))
}

# ── Duty-hour logging ──────────────────────────────────────────────────────

VERIFIED_STATUS <- c("confirmed", "entered")

# Of the days that have duty hours to report (worked days: verified, still
# the Amion estimate, or needing entry), the share residents confirmed or
# entered themselves.
duty_logging_summary <- function(d) {
  f <- function(from) {
    a <- d$activity |> filter(Date >= from, Date <= d$week$end,
                              record_id %in% d$roster$record_id,
                              duty_status %in% c(VERIFIED_STATUS, "amion_default", "needs_entry"))
    list(days = nrow(a), verified = sum(a$duty_status %in% VERIFIED_STATUS),
         residents = n_distinct(a$record_id[a$duty_status %in% VERIFIED_STATUS]))
  }
  list(week = f(d$week$start), ay = f(d$ay_start), n_residents = nrow(d$roster))
}

# ── Peer reviews ───────────────────────────────────────────────────────────

peer_summary <- function(d) {
  pe <- d$peer |>
    filter(!is.na(peer_date), peer_date >= d$ay_start, peer_date <= d$week$end,
           !is.na(peer_evaluator_id), peer_evaluator_id %in% d$roster$record_id)
  list(last4 = sum(pe$peer_date >= d$week$end - 27),
       ay = nrow(pe),
       reviewers = n_distinct(pe$peer_evaluator_id),
       n_residents = nrow(d$roster))
}

# ── MKSAP ──────────────────────────────────────────────────────────────────

# Latest export per resident vs the class goal. Expected-by-now is linear
# from July 1 to April 1, measured at the export date. Prelims have no goal.
mksap_summary <- function(d) {
  due <- as.Date(sprintf("%d-%s", d$ay + 1L, MKSAP_DUE_MMDD))
  latest <- d$mksap |>
    filter(!is.na(mk_export_date), mk_export_date <= d$as_of) |>
    group_by(record_id) |>
    arrange(mk_export_date, redcap_repeat_instance, .by_group = TRUE) |>
    slice_tail(n = 1) |>
    ungroup()
  if (!nrow(latest)) return(NULL)
  export_date <- max(latest$mk_export_date)
  frac <- min(1, max(0, as.numeric(export_date - d$ay_start) / as.numeric(due - d$ay_start)))

  by_class <- d$roster |>
    filter(!prelim) |>
    select(record_id, class) |>
    left_join(latest |> select(record_id, mk_n_complete), by = "record_id") |>
    mutate(mk_n_complete = coalesce(mk_n_complete, 0),
           goal = unname(MKSAP_GOAL[as.character(class)]),
           expected = goal * frac) |>
    group_by(class) |>
    summarise(n = n(), median_done = stats::median(mk_n_complete),
              goal = first(goal), expected = first(expected),
              on_pace = mean(mk_n_complete >= expected), .groups = "drop")
  list(export_date = export_date, due = due, by_class = by_class)
}

# ── Continuity clinic, by PCEC team ────────────────────────────────────────

academic_year_of <- function(date) {
  yr <- as.integer(format(date, "%Y"))
  ifelse(as.integer(format(date, "%m")) >= 7L, yr, yr - 1L)
}

# A Q4 evaluation dated Jul-Sep counts toward the AY that just ended.
cc_academic_year <- function(ass_date, ass_cc_quart) {
  ay <- academic_year_of(ass_date)
  late_q4 <- substr(ass_cc_quart, 1, 1) == "4" &
    as.integer(format(ass_date, "%m")) %in% 7:9
  ifelse(!is.na(late_q4) & late_q4, ay - 1L, ay)
}

is_clinic_service <- function(specialty) {
  grepl("primary care|continuity clinic", specialty, ignore.case = TRUE)
}

# Categoricals only. One row per team (plus "Program"): residents, CC
# evals done for each quarter that has opened, residents with a clinic
# observation this AY.
clinic_team_summary <- function(d) {
  acad_year <- d$ay
  roster <- d$roster |>
    filter(!prelim) |>
    mutate(team = if_else(is.na(clinic_firm) | clinic_firm == "", "No team recorded",
                          as.character(clinic_firm)))

  quarters <- tibble::tibble(
    q     = 1:4,
    start = as.Date(sprintf(c("%d-07-01", "%d-10-01", "%d-01-01", "%d-04-01"),
                            c(acad_year, acad_year, acad_year + 1L, acad_year + 1L))),
    due   = as.Date(sprintf(c("%d-09-30", "%d-12-31", "%d-03-31", "%d-06-30"),
                            c(acad_year, acad_year, acad_year + 1L, acad_year + 1L)))
  ) |>
    mutate(window = case_when(d$as_of > due    ~ "past",
                              d$as_of >= start ~ "current",
                              TRUE             ~ "future")) |>
    filter(window != "future")

  ass <- d$assessments |>
    filter(record_id %in% roster$record_id) |>
    mutate(cc_ay = cc_academic_year(ass_date, ass_cc_quart)) |>
    filter((ass_date >= d$ay_start & ass_date <= d$as_of) |
             (!is.na(ass_cc_quart) & cc_ay == acad_year)) |>
    dedupe_assessments()

  cc_done <- ass |>
    filter(!is.na(ass_cc_quart), ass_cc_quart != "", cc_ay == acad_year) |>
    mutate(q = as.integer(substr(ass_cc_quart, 1, 1))) |>
    filter(q %in% quarters$q) |>
    distinct(record_id, q)

  observed <- ass |>
    filter(ass_date >= d$ay_start, !is.na(ass_obs_type), ass_obs_type != "",
           is_clinic_service(ass_specialty)) |>
    distinct(record_id)

  per_res <- roster |>
    select(record_id, team) |>
    tidyr::crossing(q = quarters$q) |>
    left_join(cc_done |> mutate(done = TRUE), by = c("record_id", "q")) |>
    mutate(done = coalesce(done, FALSE))

  team_rows <- function(x, obs_ids) {
    x |>
      group_by(team) |>
      summarise(residents = n_distinct(record_id),
                !!!setNames(lapply(quarters$q, function(qq) rlang::expr(sum(done[q == !!qq]))),
                            paste0("Q", quarters$q)),
                observed = n_distinct(record_id[record_id %in% obs_ids]),
                .groups = "drop")
  }
  teams <- team_rows(per_res, observed$record_id)
  teams <- teams[order(teams$team == "No team recorded", teams$team), ]
  program <- team_rows(per_res |> mutate(team = "Program"), observed$record_id)
  list(quarters = quarters, teams = bind_rows(teams, program))
}
