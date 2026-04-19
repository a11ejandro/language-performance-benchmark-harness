require 'rails_helper'

RSpec.describe 'Durations selected CSV', type: :request do
  it 'returns a CSV attachment with expected header and rows' do
    t1 = Task.create!(name: 'Alpha', selected: true)
    t2 = Task.create!(name: 'Beta', selected: true)
    h1 = Handler.create!(task: t1, handler_type: 'go')
    run1 = TestRun.create!(handler: h1)
    TestResult.create!(test_run: run1, duration: 1.2345)
    TestResult.create!(test_run: run1, duration: 2)

    h2 = Handler.create!(task: t2, handler_type: 'ruby')
    run2 = TestRun.create!(handler: h2)
    TestResult.create!(test_run: run2, duration: 9)

    get durations_selected_csv_path

    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Type']).to include('text/csv')
    expect(response.headers['Content-Disposition']).to include('selected_tasks_durations_')

    body = response.body
    lines = body.split("\n")

    expect(lines.first).to eq('task,handler_type,index,duration')
    expect(body).to include('Alpha,go,0,1.234500')
    expect(body).to include('Alpha,go,1,2.000000')
    expect(body).to include('Beta,ruby,0,9.000000')
  end
end
