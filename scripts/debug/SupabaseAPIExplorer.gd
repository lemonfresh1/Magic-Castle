# SupabaseAPIExplorer.gd - Explore available Supabase plugin methods
# Location: res://Pyramids/scripts/test/SupabaseAPIExplorer.gd
# Purpose: Find out what methods are actually available in the plugin

extends Control

func _ready():
	print("=== Supabase API Explorer ===")
	
	# Check what we have
	if not has_node("/root/Supabase"):
		print("❌ Supabase autoload not found")
		return
	
	print("✅ Supabase autoload found")
	
	# Explore Auth API
	print("\n--- AUTH API ---")
	if Supabase.auth:
		print("Auth object type: %s" % Supabase.auth.get_class())
		var auth_methods = Supabase.auth.get_method_list()
		print("Auth methods available:")
		for method in auth_methods:
			if not method.name.begins_with("_"):  # Skip private methods
				print("  • %s" % method.name)
	
	# Explore Database API
	print("\n--- DATABASE API ---")
	if Supabase.database:
		print("Database object type: %s" % Supabase.database.get_class())
		var db_methods = Supabase.database.get_method_list()
		print("Database methods available:")
		for method in db_methods:
			if not method.name.begins_with("_"):  # Skip private methods
				print("  • %s" % method.name)
	
	# Explore Realtime API
	print("\n--- REALTIME API ---")
	if Supabase.realtime:
		print("Realtime object type: %s" % Supabase.realtime.get_class())
		var rt_methods = Supabase.realtime.get_method_list()
		print("Realtime methods available:")
		for method in rt_methods:
			if not method.name.begins_with("_"):  # Skip private methods
				print("  • %s" % method.name)
	
	# Check for signals
	print("\n--- AUTH SIGNALS ---")
	if Supabase.auth:
		var auth_signals = Supabase.auth.get_signal_list()
		print("Auth signals available:")
		for sig in auth_signals:
			print("  • %s" % sig.name)
	
	print("\n=== End API Explorer ===")
	
	# Try to find the correct method names
	print("\n--- CHECKING METHOD EXISTENCE ---")
	
	# Database methods
	if Supabase.database.has_method("query"):
		print("✅ database.query() exists")
	if Supabase.database.has_method("select"):
		print("✅ database.select() exists")
	if Supabase.database.has_method("from"):
		print("✅ database.from() exists")
	if Supabase.database.has_method("rpc"):
		print("✅ database.rpc() exists")
	
	# Auth methods
	if Supabase.auth.has_method("sign_up"):
		print("✅ auth.sign_up() exists")
	if Supabase.auth.has_method("sign_in"):
		print("✅ auth.sign_in() exists")
	if Supabase.auth.has_method("sign_in_with_password"):
		print("✅ auth.sign_in_with_password() exists")
	if Supabase.auth.has_method("sign_in_anonymously"):
		print("✅ auth.sign_in_anonymously() exists")
	if Supabase.auth.has_method("sign_out"):
		print("✅ auth.sign_out() exists")
