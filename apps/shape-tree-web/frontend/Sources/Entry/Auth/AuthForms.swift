import JavaScriptKit
import ShapeTreeDOM

func submitLoginForm(
  emailInput: JSValue,
  next: String,
  status: JSValue,
  submitButton: JSValue,
  shell: AppShell
) {
  guard let email = emailInput.value.string, !email.isEmpty else { return }
  let body = "email=\(formURLEncode(email))&next=\(formURLEncode(next))"

  setInnerText(status, "Sending…")
  submitButton.disabled = .boolean(true)

  let promise = postFormURL("/auth/login", body: body)
  promise.then(success: { response in
    if response.ok.boolean == true {
      navigateToCheckEmail(shell: shell)
    } else {
      setInnerText(status, "Something went wrong. Try again.")
      submitButton.disabled = .boolean(false)
    }
    return JSValue.undefined
  })
  promise.catch(failure: { _ in
    setInnerText(status, "Something went wrong. Try again.")
    submitButton.disabled = .boolean(false)
    return JSValue.undefined
  })
}

func submitVerifyForm(
  token: String,
  next: String,
  status: JSValue,
  submitButton: JSValue,
  shell: AppShell
) {
  let body = "token=\(formURLEncode(token))&next=\(formURLEncode(next))"

  setInnerText(status, "Signing in…")
  submitButton.disabled = .boolean(true)

  let promise = postFormURL("/auth/verify", body: body)
  promise.then(success: { response in
    let jsonPromise = responseJSON(response)
    jsonPromise.then(success: { jsonValue in
      guard let body = jsonValue.object else {
        setInnerText(status, "Something went wrong. Try again.")
        submitButton.disabled = .boolean(false)
        return JSValue.undefined
      }
      let result = VerifyResponse(unsafelyCopying: body)
      if result.ok {
        refreshSessionTabs(shell: shell, openFitIfSignedIn: true)
        navigateAfterSignIn(shell: shell, next: result.next ?? "/")
      } else {
        navigateToVerify(shell: shell)
      }
      return JSValue.undefined
    })
    jsonPromise.catch(failure: { _ in
      setInnerText(status, "Something went wrong. Try again.")
      submitButton.disabled = .boolean(false)
      return JSValue.undefined
    })
    return JSValue.undefined
  })
  promise.catch(failure: { _ in
    setInnerText(status, "Something went wrong. Try again.")
    submitButton.disabled = .boolean(false)
    return JSValue.undefined
  })
}
