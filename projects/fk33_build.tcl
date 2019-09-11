
synth_design -top bd_wrapper
report_qor_suggestions -file post_synth_suggestions.rpt 
opt_design 
report_qor_suggestions -file post_opt_suggestions.rpt
place_design
report_qor_suggestions -file post_place_suggestions.rpt
route_design
report_qor_suggestions -file post_route_suggestions.rpt
set_property ENABLED 1 [get_qor_suggestions]
write_qor_suggestions -force all_enabled_suggestions.rqs
