library(shinytest2)

app <- AppDriver$new(".", seed = 123)

# Verify initial plot renders
app$expect_snapshot(output = "main_plot")

# Click Regenerate and ensure new data appears
app$click("regen")
app$wait_for_idle()
app$expect_snapshot(output = "main_plot")

# Toggle plane off
app$set_inputs(show_plane = FALSE)
app$wait_for_idle()
app$expect_snapshot(output = "main_plot")
