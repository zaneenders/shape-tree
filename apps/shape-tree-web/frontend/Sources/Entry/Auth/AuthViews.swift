import JavaScriptKit
import ShapeTreeDOM

func renderAuthView(into container: JSValue, props: PageProps, shell: AppShell) {
  let main = createElement("main", className: "auth-page")
  append(main, to: container)

  switch props.page {
  case "login":
    let heading = createElement("h1", innerText: "Sign in")
    append(heading, to: main)

    let blurb = createElement(
      "p",
      innerText: "Enter your email and we will send you a one-time sign-in link."
    )
    append(blurb, to: main)

    let form = createElement("form", className: "auth-form")
    append(form, to: main)

    let emailLabel = createElement("label", innerText: "Email")
    append(emailLabel, to: form)

    let emailInput = createElement(
      "input",
      attributes: [
        "type": "email",
        "name": "email",
        "required": "true",
        "autocomplete": "email",
      ]
    )
    append(emailInput, to: emailLabel)

    let nextInput = createElement(
      "input",
      attributes: ["type": "hidden", "name": "next", "value": props.next]
    )
    append(nextInput, to: form)

    let status = createElement("p", className: "status", id: "login-status")
    append(status, to: form)

    let submitButton = createElement(
      "button",
      innerText: "Send sign-in link",
      attributes: ["type": "submit"]
    )
    append(submitButton, to: form)

    form.onsubmit = .object(
      JSClosure { arguments -> JSValue in
        if let event = arguments[0].object {
          _ = event.preventDefault!()
        }
        submitLoginForm(
          emailInput: emailInput,
          next: props.next,
          status: status,
          submitButton: submitButton,
          shell: shell
        )
        return .undefined
      }
    )

  case "check-email":
    let heading = createElement("h1", innerText: "Check your email")
    append(heading, to: main)

    let p1 = createElement(
      "p",
      innerText:
        "If an account exists for that address, we sent a sign-in link. The link expires soon and works once."
    )
    append(p1, to: main)

    append(createSpaLink(shell: shell, route: .login(next: "/"), text: "Back to sign in"), to: main)

  case "verify":
    if !props.token.isEmpty {
      let heading = createElement("h1", innerText: "Confirm sign in")
      append(heading, to: main)

      let blurb = createElement("p", innerText: "Click continue to finish signing in.")
      append(blurb, to: main)

      let form = createElement("form", className: "auth-form")
      append(form, to: main)

      let status = createElement("p", className: "status", id: "verify-status")
      append(status, to: form)

      let submitButton = createElement(
        "button",
        innerText: "Continue",
        attributes: ["type": "submit"]
      )
      append(submitButton, to: form)

      form.onsubmit = .object(
        JSClosure { arguments -> JSValue in
          if let event = arguments[0].object {
            _ = event.preventDefault!()
          }
          submitVerifyForm(
            token: props.token,
            next: props.next,
            status: status,
            submitButton: submitButton,
            shell: shell
          )
          return .undefined
        }
      )
    } else {
      let heading = createElement("h1", innerText: "Sign-in link invalid")
      append(heading, to: main)

      let blurb = createElement(
        "p",
        innerText: "This link is missing, expired, or already used."
      )
      append(blurb, to: main)

      append(createSpaLink(shell: shell, route: .login(next: "/"), text: "Request a new sign-in link"), to: main)
    }

  default:
    break
  }
}

func createSpaLink(shell: AppShell, route: ClientRoute, text: String) -> JSValue {
  let button = createElement(
    "button",
    className: "text-link",
    innerText: text,
    attributes: ["type": "button"]
  )
  button.onclick = .object(
    JSClosure { _ -> JSValue in
      switch route {
      case .home:
        navigateToHome(shell: shell)
      case .login(let next):
        navigateToLogin(shell: shell, next: next)
      case .checkEmail:
        navigateToCheckEmail(shell: shell)
      case .verify:
        navigateToVerify(shell: shell)
      }
      return .undefined
    }
  )
  return button
}
