local domain = os.getenv("WINGFTP_BOOTSTRAP_DOMAIN") or "lab"
domain = string.gsub(domain, "^['\"](.-)['\"]$", "%1")

local exists = false
for _, d in pairs(c_GetDomainList()) do
  if d == domain then
    exists = true
  end
end

if not exists then
  c_AddDomain(domain, "*", 21, -1, -1, -1, -1)
end

c_AddListener(domain, 1, "*", 21, "", 0)

-- Create anonymous FTP account with empty password hash and map it to /anonymous.
pcall(function()
  c_AddUser(domain, "anonymous", md5(""), 63, 1, 1)
end)

pcall(function()
  c_AddUserDirectory(
    domain,
    "anonymous",
    "/opt/wingftpd/ftp/anonymous",
    "/",
    true,
    true,
    false,
    false,
    false,
    true,
    false,
    false,
    false
  )
end)
