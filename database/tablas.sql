    Tables (28 total):

     1 [{"name":"error_handling.error_aggregations","cols":[{"name":"id","type":"bigint","null":false,"pk":true},{"name"
       :"workflow_name","type":"character varying(255)","null":false},{"name":"error_type","type":"character 
       varying(100)","null":false},{"name":"error_fingerprint","type":"character varying(64)","null":true},{"name":
       "time_window_start","type":"timestamp with time zone","null":false},{"name":"time_window_end","type":"timestamp 
       with time zone","null":false},{"name":"occurrence_count","type":"integer","null":true},{"name":"severity_max",
       "type":"character varying(20)","null":true},{"name":"first_occurrence","type":"timestamp with time zone","null":
       true},{"name":"last_occurrence","type":"timestamp with time zone","null":true},{"name":"created_at","type":
       "timestamp with time zone","null":true},{"name":"updated_at","type":"timestamp with time zone","null":true}],"pk"
       :["id"],"idx":["idx_error_aggregations_lookup"],"enums":{}},{"name":"error_handling.error_logs","cols":[{"name":
       "id","type":"bigint","null":false,"pk":true},{"name":"workflow_name","type":"character varying(255)","null":false
       },{"name":"error_type","type":"character varying(100)","null":false},{"name":"error_message","type":"text","null"
       :false},{"name":"error_fingerprint","type":"character varying(64)","null":true},{"name":"severity","type":
       "character varying(20)","null":true},{"name":"occurrences","type":"integer","null":true},{"name":"metadata",
       "type":"jsonb","null":true},{"name":"input_data","type":"jsonb","null":true},{"name":"stack_trace","type":"text",
       "null":true},{"name":"user_id","type":"character varying(100)","null":true},{"name":"session_id","type":
       "character varying(100)","null":true},{"name":"environment","type":"character varying(50)","null":true},{"name":
       "resolved","type":"boolean","null":true},{"name":"resolved_at","type":"timestamp with time zone","null":true},{
       "name":"resolved_by","type":"character varying(100)","null":true},{"name":"created_at","type":"timestamp with 
       time zone","null":true},{"name":"updated_at","type":"timestamp with time zone","null":true}],"pk":["id"],"idx":[
       "idx_error_logs_created_at","idx_error_logs_environment","idx_error_logs_fingerprint",
       "idx_error_logs_high_severity","idx_error_logs_recurrence","idx_error_logs_unresolved"],"enums":{}},{"name":
       "error_handling.recurrence_config","cols":[{"name":"id","type":"integer","null":false,"pk":true},{"name":
       "workflow_name","type":"character varying(255)","null":true},{"name":"error_type","type":"character varying(100)"
       ,"null":true},{"name":"time_window_minutes","type":"integer","null":true},{"name":"threshold_low","type":
       "integer","null":true},{"name":"threshold_medium","type":"integer","null":true},{"name":"threshold_high","type":
       "integer","null":true},{"name":"threshold_critical","type":"integer","null":true},{"name":"enabled","type":
       "boolean","null":true},{"name":"created_at","type":"timestamp with time zone","null":true},{"name":"updated_at",
       "type":"timestamp with time zone","null":true}],"pk":["id"],"idx":[],"enums":{}},{"name":"neon_auth.account",
       "cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":"accountId","type":"text","null":false},{
       "name":"providerId","type":"text","null":false},{"name":"userId","type":"uuid","null":false},{"name":
       "accessToken","type":"text","null":true},{"name":"refreshToken","type":"text","null":true},{"name":"idToken",
       "type":"text","null":true},{"name":"accessTokenExpiresAt","type":"timestamp with time zone","null":true},{"name":
       "refreshTokenExpiresAt","type":"timestamp with time zone","null":true},{"name":"scope","type":"text","null":true}
       ,{"name":"password","type":"text","null":true},{"name":"createdAt","type":"timestamp with time zone","null":false
       },{"name":"updatedAt","type":"timestamp with time zone","null":false}],"pk":["id"],"idx":["account_userId_idx"],
       "enums":{}},{"name":"neon_auth.invitation","cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":
       "organizationId","type":"uuid","null":false},{"name":"email","type":"text","null":false},{"name":"role","type":
       "text","null":true},{"name":"status","type":"text","null":false},{"name":"expiresAt","type":"timestamp with time 
       zone","null":false},{"name":"createdAt","type":"timestamp with time zone","null":false},{"name":"inviterId",
       "type":"uuid","null":false}],"pk":["id"],"idx":["invitation_email_idx","invitation_organizationId_idx"],"enums":{
       }},{"name":"neon_auth.jwks","cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":"publicKey","type"
       :"text","null":false},{"name":"privateKey","type":"text","null":false},{"name":"createdAt","type":"timestamp with
       time zone","null":false},{"name":"expiresAt","type":"timestamp with time zone","null":true}],"pk":["id"],"idx":[]
       ,"enums":{}},{"name":"neon_auth.member","cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":
       "organizationId","type":"uuid","null":false},{"name":"userId","type":"uuid","null":false},{"name":"role","type":
       "text","null":false},{"name":"createdAt","type":"timestamp with time zone","null":false}],"pk":["id"],"idx":[
       "member_organizationId_idx","member_userId_idx"],"enums":{}},{"name":"neon_auth.organization","cols":[{"name":
       "id","type":"uuid","null":false,"pk":true},{"name":"name","type":"text","null":false},{"name":"slug","type":
       "text","null":false},{"name":"logo","type":"text","null":true},{"name":"createdAt","type":"timestamp with time 
       zone","null":false},{"name":"metadata","type":"text","null":true}],"pk":["id"],"idx":[],"enums":{}},{"name":
       "neon_auth.project_config","cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":"name","type":
       "text","null":false},{"name":"endpoint_id","type":"text","null":false},{"name":"created_at","type":"timestamp 
       with time zone","null":false},{"name":"updated_at","type":"timestamp with time zone","null":false},{"name":
       "trusted_origins","type":"jsonb","null":false},{"name":"social_providers","type":"jsonb","null":false},{"name":
       "email_provider","type":"jsonb","null":true},{"name":"email_and_password","type":"jsonb","null":true},{"name":
       "allow_localhost","type":"boolean","null":false}],"pk":["id"],"idx":[],"enums":{}},{"name":"neon_auth.session",
       "cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":"expiresAt","type":"timestamp with time zone",
       "null":false},{"name":"token","type":"text","null":false},{"name":"createdAt","type":"timestamp with time zone",
       "null":false},{"name":"updatedAt","type":"timestamp with time zone","null":false},{"name":"ipAddress","type":
       "text","null":true},{"name":"userAgent","type":"text","null":true},{"name":"userId","type":"uuid","null":false},{
       "name":"impersonatedBy","type":"text","null":true},{"name":"activeOrganizationId","type":"text","null":true}],
       "pk":["id"],"idx":["session_userId_idx"],"enums":{}},{"name":"neon_auth.user","cols":[{"name":"id","type":"uuid",
       "null":false,"pk":true},{"name":"name","type":"text","null":false},{"name":"email","type":"text","null":false},{
       "name":"emailVerified","type":"boolean","null":false},{"name":"image","type":"text","null":true},{"name":
       "createdAt","type":"timestamp with time zone","null":false},{"name":"updatedAt","type":"timestamp with time zone"
       ,"null":false},{"name":"role","type":"text","null":true},{"name":"banned","type":"boolean","null":true},{"name":
       "banReason","type":"text","null":true},{"name":"banExpires","type":"timestamp with time zone","null":true}],"pk":
       ["id"],"idx":[],"enums":{}},{"name":"neon_auth.verification","cols":[{"name":"id","type":"uuid","null":false,"pk"
       :true},{"name":"identifier","type":"text","null":false},{"name":"value","type":"text","null":false},{"name":
       "expiresAt","type":"timestamp with time zone","null":false},{"name":"createdAt","type":"timestamp with time zone"
       ,"null":false},{"name":"updatedAt","type":"timestamp with time zone","null":false}],"pk":["id"],"idx":[
       "verification_identifier_idx"],"enums":{}},{"name":"public.admin_sessions","cols":[{"name":"id","type":"uuid",
       "null":false,"pk":true},{"name":"user_id","type":"uuid","null":false},{"name":"token_hash","type":"text","null":
       false},{"name":"expires_at","type":"timestamp with time zone","null":false},{"name":"created_at","type":
       "timestamp with time zone","null":true},{"name":"last_used_at","type":"timestamp with time zone","null":true},{
       "name":"is_revoked","type":"boolean","null":true}],"pk":["id"],"idx":["idx_admin_sessions_expires_at",
       "idx_admin_sessions_last_used","idx_admin_sessions_token_hash","idx_admin_sessions_user_id"],"enums":{}},{"name":
       "public.admin_users","cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":"username","type":
       "character varying(50)","null":false},{"name":"password_hash","type":"text","null":false},{"name":"role","type":
       "character varying(20)","null":true},{"name":"is_active","type":"boolean","null":true},{"name":"created_at",
       "type":"timestamp with time zone","null":true},{"name":"updated_at","type":"timestamp with time zone","null":true
       }],"pk":["id"],"idx":["idx_admin_users_username"],"enums":{}},{"name":"public.app_config","cols":[{"name":"id",
       "type":"uuid","null":false,"pk":true},{"name":"key","type":"character varying(100)","null":false},{"name":"value"
       ,"type":"text","null":false},{"name":"type","type":"character varying(20)","null":true},{"name":"category","type"
       :"character varying(50)","null":true},{"name":"description","type":"text","null":true},{"name":"is_public","type"
       :"boolean","null":true},{"name":"created_at","type":"timestamp with time zone","null":true},{"name":"updated_at",
       "type":"timestamp with time zone","null":true}],"pk":["id"],"idx":["idx_app_config_category",
       "idx_app_config_key_category"],"enums":{}},{"name":"public.app_messages","cols":[{"name":"id","type":"uuid",
       "null":false,"pk":true},{"name":"code","type":"character varying(50)","null":false},{"name":"lang","type":
       "character varying(10)","null":false},{"name":"message","type":"text","null":false},{"name":"created_at","type":
       "timestamp with time zone","null":true},{"name":"updated_at","type":"timestamp with time zone","null":true}],"pk"
       :["id"],"idx":["idx_app_messages_lookup"],"enums":{}},{"name":"public.audit_logs","cols":[{"name":"id","type":
       "uuid","null":false,"pk":true},{"name":"table_name","type":"text","null":false},{"name":"record_id","type":"uuid"
       ,"null":false},{"name":"action","type":"public.audit_action","null":false,"enum":["INSERT","UPDATE","SOFT_DELETE"
       ,"HARD_DELETE","LOGIN_ATTEMPT","SECURITY_BLOCK","DEEP_LINK_ACCESS","DEEP_LINK_FAILURE","ACCESS_CHECK",
       "ACCESS_DENIED"]},{"name":"old_values","type":"jsonb","null":true},{"name":"new_values","type":"jsonb","null":
       true},{"name":"performed_by","type":"text","null":true},{"name":"ip_address","type":"inet","null":true},{"name":
       "created_at","type":"timestamp with time zone","null":true},{"name":"event_type","type":"text","null":true},{
       "name":"event_data","type":"jsonb","null":true}],"pk":["id"],"idx":["idx_audit_logs_timestamp"],"enums":{"action"
       :["INSERT","UPDATE","SOFT_DELETE","HARD_DELETE","LOGIN_ATTEMPT","SECURITY_BLOCK","DEEP_LINK_ACCESS",
       "DEEP_LINK_FAILURE","ACCESS_CHECK","ACCESS_DENIED"]}},{"name":"public.bookings","cols":[{"name":"id","type":
       "uuid","null":false,"pk":true},{"name":"user_id","type":"uuid","null":false},{"name":"provider_id","type":"uuid",
       "null":false},{"name":"service_id","type":"uuid","null":true},{"name":"start_time","type":"timestamp with time 
       zone","null":false},{"name":"end_time","type":"timestamp with time zone","null":false},{"name":"status","type":
       "public.booking_status","null":true,"enum":["pending","confirmed","cancelled","completed","no_show","rescheduled"
       ]},{"name":"gcal_event_id","type":"text","null":true},{"name":"notes","type":"text","null":true},{"name":
       "created_at","type":"timestamp with time zone","null":true},{"name":"updated_at","type":"timestamp with time 
       zone","null":true},{"name":"deleted_at","type":"timestamp with time zone","null":true},{"name":
       "reminder_1_sent_at","type":"timestamp with time zone","null":true},{"name":"reminder_2_sent_at","type":
       "timestamp with time zone","null":true}],"pk":["id"],"idx":["idx_bookings_provider","idx_bookings_provider_time",
       "idx_bookings_range","idx_bookings_reminder_1","idx_bookings_reminder_2","idx_bookings_reminders",
       "idx_bookings_start_time","idx_bookings_user"],"enums":{"status":["pending","confirmed","cancelled","completed",
       "no_show","rescheduled"]}},{"name":"public.circuit_breaker_state","cols":[{"name":"id","type":"uuid","null":false
       ,"pk":true},{"name":"workflow_name","type":"character varying(200)","null":false},{"name":"state","type":
       "character varying(20)","null":true},{"name":"failure_count","type":"integer","null":true},{"name":
       "last_failure_at","type":"timestamp with time zone","null":true},{"name":"opened_at","type":"timestamp with time 
       zone","null":true},{"name":"next_attempt_at","type":"timestamp with time zone","null":true},{"name":"created_at",
       "type":"timestamp with time zone","null":true},{"name":"updated_at","type":"timestamp with time zone","null":true
       }],"pk":["id"],"idx":["idx_circuit_breaker_workflow"],"enums":{}},{"name":"public.error_metrics","cols":[{"name":
       "id","type":"uuid","null":false,"pk":true},{"name":"metric_date","type":"date","null":false},{"name":
       "workflow_name","type":"character varying(200)","null":false},{"name":"severity","type":"character varying(20)",
       "null":false},{"name":"error_count","type":"integer","null":true},{"name":"first_occurrence","type":"timestamp 
       with time zone","null":true},{"name":"last_occurrence","type":"timestamp with time zone","null":true},{"name":
       "created_at","type":"timestamp with time zone","null":true},{"name":"updated_at","type":"timestamp with time 
       zone","null":true}],"pk":["id"],"idx":["idx_error_metrics_date"],"enums":{}},{"name":
       "public.notification_configs","cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":
       "reminder_1_hours","type":"integer","null":true},{"name":"reminder_2_hours","type":"integer","null":true},{"name"
       :"is_active","type":"boolean","null":true},{"name":"created_at","type":"timestamp with time zone","null":true},{
       "name":"updated_at","type":"timestamp with time zone","null":true},{"name":"default_duration_min","type":
       "integer","null":true},{"name":"min_duration_min","type":"integer","null":true},{"name":"max_duration_min","type"
       :"integer","null":true}],"pk":["id"],"idx":[],"enums":{}},{"name":"public.notification_queue","cols":[{"name":
       "id","type":"uuid","null":false,"pk":true},{"name":"booking_id","type":"uuid","null":true},{"name":"user_id",
       "type":"uuid","null":true},{"name":"message","type":"text","null":false},{"name":"priority","type":"integer",
       "null":true},{"name":"status","type":"public.notification_status","null":true,"enum":["pending","sent","failed"]}
       ,{"name":"retry_count","type":"integer","null":true},{"name":"error_message","type":"text","null":true},{"name":
       "created_at","type":"timestamp with time zone","null":true},{"name":"updated_at","type":"timestamp with time 
       zone","null":true},{"name":"sent_at","type":"timestamp with time zone","null":true},{"name":"next_retry_at",
       "type":"timestamp with time zone","null":true},{"name":"channel","type":"character varying(50)","null":true},{
       "name":"recipient","type":"text","null":true},{"name":"payload","type":"jsonb","null":true},{"name":"max_retries"
       ,"type":"integer","null":true},{"name":"expires_at","type":"timestamp with time zone","null":true}],"pk":["id"],
       "idx":["idx_notification_queue_booking_id","idx_notification_queue_created_at","idx_notification_queue_pending",
       "idx_notification_queue_priority","idx_notification_queue_retry","idx_notification_queue_status",
       "idx_notification_queue_user_id"],"enums":{"status":["pending","sent","failed"]}},{"name":"public.providers",
       "cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":"user_id","type":"uuid","null":true},{"name":
       "name","type":"text","null":false},{"name":"email","type":"public.citext","null":true},{"name":
       "google_calendar_id","type":"text","null":true},{"name":"slot_duration_minutes","type":"integer","null":true},{
       "name":"min_notice_hours","type":"integer","null":true},{"name":"public_booking_enabled","type":"boolean","null":
       true},{"name":"created_at","type":"timestamp with time zone","null":true},{"name":"deleted_at","type":"timestamp 
       with time zone","null":true},{"name":"slug","type":"text","null":true},{"name":"slot_duration_mins","type":
       "integer","null":false}],"pk":["id"],"idx":[],"enums":{}},{"name":"public.schedules","cols":[{"name":"id","type":
       "uuid","null":false,"pk":true},{"name":"provider_id","type":"uuid","null":false},{"name":"day_of_week","type":
       "public.day_of_week","null":false,"enum":["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
       },{"name":"start_time","type":"time without time zone","null":false},{"name":"end_time","type":"time without time
       zone","null":false},{"name":"is_active","type":"boolean","null":true}],"pk":["id"],"idx":["idx_schedules_pro"],
       "enums":{"day_of_week":["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]}},{"name":
       "public.security_firewall","cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":"entity_id","type":
       "text","null":false},{"name":"strike_count","type":"integer","null":true},{"name":"is_blocked","type":"boolean",
       "null":true},{"name":"blocked_until","type":"timestamp with time zone","null":true},{"name":"last_strike_at",
       "type":"timestamp with time zone","null":true},{"name":"created_at","type":"timestamp with time zone","null":true
       },{"name":"updated_at","type":"timestamp with time zone","null":true}],"pk":["id"],"idx":["idx_firewall_entity",
       "idx_security_firewall_entity"],"enums":{}},{"name":"public.services","cols":[{"name":"id","type":"uuid","null":
       false,"pk":true},{"name":"provider_id","type":"uuid","null":false},{"name":"name","type":"text","null":false},{
       "name":"description","type":"text","null":true},{"name":"duration_minutes","type":"integer","null":false},{"name"
       :"price","type":"numeric(10,2)","null":true},{"name":"tier","type":"public.service_tier","null":true,"enum":[
       "standard","premium","emergency"]},{"name":"active","type":"boolean","null":true}],"pk":["id"],"idx":[],"enums":{
       "tier":["standard","premium","emergency"]}},{"name":"public.system_errors","cols":[{"name":"error_id","type":
       "uuid","null":false,"pk":true},{"name":"workflow_name","type":"text","null":true},{"name":"workflow_execution_id"
       ,"type":"text","null":true},{"name":"error_type","type":"text","null":true},{"name":"severity","type":"text",
       "null":true},{"name":"error_message","type":"text","null":true},{"name":"error_stack","type":"text","null":true},
       {"name":"error_context","type":"jsonb","null":true},{"name":"user_id","type":"uuid","null":true},{"name":
       "created_at","type":"timestamp with time zone","null":true},{"name":"resolved_at","type":"timestamp with time 
       zone","null":true},{"name":"is_resolved","type":"boolean","null":true},{"name":"resolution_notes","type":"text",
       "null":true}],"pk":["error_id"],"idx":["idx_se_created","idx_se_severity","idx_se_workflow",
       "idx_system_errors_created","idx_system_errors_created_at","idx_system_errors_severity",
       "idx_system_errors_unresolved","idx_system_errors_workflow","idx_system_errors_workflow_created"],"enums":{}},{
       "name":"public.users","cols":[{"name":"id","type":"uuid","null":false,"pk":true},{"name":"telegram_id","type":
       "bigint","null":false},{"name":"first_name","type":"text","null":true},{"name":"last_name","type":"text","null":
       true},{"name":"username","type":"text","null":true},{"name":"phone_number","type":"text","null":true},{"name":
       "rut","type":"text","null":true},{"name":"role","type":"public.user_role","null":true,"enum":["user","admin",
       "system"]},{"name":"language_code","type":"public.supported_lang","null":true,"enum":["es","en","pt"]},{"name":
       "metadata","type":"jsonb","null":true},{"name":"created_at","type":"timestamp with time zone","null":true},{
       "name":"updated_at","type":"timestamp with time zone","null":true},{"name":"deleted_at","type":"timestamp with 
       time zone","null":true},{"name":"password_hash","type":"text","null":true},{"name":"last_selected_provider_id",
       "type":"uuid","null":true}],"pk":["id"],"idx":["idx_users_role","idx_users_telegram"],"enums":{"role":["user",
       "admin","system"],"language_code":["es","en","pt"]}}]

