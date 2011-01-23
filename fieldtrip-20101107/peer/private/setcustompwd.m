function setcustompwd(option_pwd)

% these are for remembering the path on subsequent calls with the same input arguments
persistent previous_argin previous_pwd

if isequal(previous_argin, option_pwd) && isequal(previous_pwd, pwd)
  % no reason to change the pwd again
  return
end

if ~isempty(option_pwd)
  try
    cd(option_pwd);
  catch cd_error
    % don't throw an error, just give a warning (and hope for the best...)
    warning(cd_error.message);
  end
end

% remember the current settings for the next call
previous_argin = option_pwd;
previous_pwd   = pwd;

