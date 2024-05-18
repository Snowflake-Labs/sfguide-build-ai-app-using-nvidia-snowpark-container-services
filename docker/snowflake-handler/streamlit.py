import streamlit as st
import os
import json
from openai import OpenAI

model=os.environ["OPENAI_MODEL"]

client=OpenAI()

st.set_page_config(
   layout="wide",
   page_title="NVIDIA: Conversation Bot"
)

temperature = st.sidebar.slider("Temperature ", 0.0, 1.0, 0.2, 0.05)
max_tokens = st.sidebar.slider("Max Tokens ", 0, 1000, 500, 5)

def main():
    if "messages" not in st.session_state:
        st.session_state.messages = [{"role": "assistant", "content": "How can i help you?"}]

    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    prompt = st.chat_input()
    if prompt:
        try:
            st.session_state.messages.append({"role": "user", "content": prompt})
            st.chat_message("user").markdown(prompt)
            with st.chat_message("assistant"):
                message = st.empty()
                with st.spinner('loading ...'):
                    response = call_llm(st.session_state.messages, max_tokens, temperature)
                st.success('Done!')
                message.markdown(response)
            st.session_state.messages.append({"role": "assistant", "content": response})
        except:
            st.error("You have used too many tokens. Let's start over")
            st.session_state.messages = []


def call_llm( messages, max_tokens, temperature) -> str:
    def convert_messages(messages) -> str:
        out = ""
        for msg in messages:
            if msg.get("role") == "user":
                out += f' [INST] {msg.get("content")} [/INST] '
            else:
                out += f' {msg.get("content")} '
        return out
    prompt = convert_messages(messages)
    response=client.completions.create(
        model=model,
        prompt=prompt,
        max_tokens=max_tokens,
        temperature=temperature
    )
    return response.choices[0].text

if __name__ == "__main__":
    main()
