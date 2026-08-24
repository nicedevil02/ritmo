/**
 * Appwrite Cloud Core Function
 * Phone OTP and Server AI Proxy routes have been decommissioned.
 */
module.exports = async function (context) {
  return context.res.json({ success: false, error: 'Endpoint deprecated' }, 404);
};
