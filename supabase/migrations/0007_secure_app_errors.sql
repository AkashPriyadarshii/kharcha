-- Secure app_errors against DOS/spam via public anon key (free tier storage exhaustion)
ALTER TABLE public.app_errors
  ADD CONSTRAINT app_errors_module_len CHECK (char_length(module) <= 150),
  ADD CONSTRAINT app_errors_event_len CHECK (char_length(event) <= 250),
  ADD CONSTRAINT app_errors_error_len CHECK (char_length(error) <= 3000),
  ADD CONSTRAINT app_errors_stack_len CHECK (char_length(stack) <= 15000);
