import unittest
import requests
import os
import json

LISTEN_URI = os.getenv('LISTEN_URI')
SERVER_IP = os.getenv('SERVER_IP')
SERVER_PORT = os.getenv('SERVER_PORT')
URL = 'http://' + SERVER_IP + ':' + SERVER_PORT + '/kv'


class TestLuaServer(unittest.TestCase):

    def test_post_success(self):
        data = [
            {'key': 'one', 'value': json.dumps('1')}
        ]
        requests.delete(URL + '/' + data[0]['key'])
        self.assertEqual(requests.post(URL, json=data[0]).status_code, 200)
        self.assertEqual(requests.delete(URL + '/' + data[0]['key']).status_code, 200)

    def test_post_already_exist(self):
        data = [
            {'key': 'one', 'value': json.dumps('1')}
        ]
        requests.delete(URL + '/' + data[0]['key'])
        self.assertEqual(requests.post(URL, json=data[0]).status_code, 200)
        self.assertEqual(requests.post(URL, json=data[0]).status_code, 409)
        self.assertEqual(requests.delete(URL + '/' + data[0]['key']).status_code, 200)

    def test_post_invalid_data(self):
        data = [
            {'key': 3, 'value': json.dumps(0)},
            {'keys': '4', 'value': json.dumps(['a', 'b'])},
            {'key': '5', 'val': json.dumps([])},
            {'key': '6', 'value': 's'}
        ]
        self.assertEqual(requests.post(URL, json=data[0]).status_code, 400)
        self.assertEqual(requests.post(URL, json=data[1]).status_code, 400)
        self.assertEqual(requests.post(URL, json=data[2]).status_code, 400)
        self.assertEqual(requests.post(URL, json=data[3]).status_code, 400)

    def test_get_success(self):
        data = [
            {'key': 'equation', 'value': json.dumps({'12+34': 46})},
        ]
        requests.delete(URL + '/' + data[0]['key'])
        self.assertEqual(requests.post(URL, json=data[0]).status_code, 200)
        self.assertEqual(requests.get(URL + '/' + data[0]['key']).status_code, 200)
        self.assertEqual(requests.get(URL + '/' + data[0]['key']).text, data[0]['value'])
        self.assertEqual(requests.delete(URL + '/' + data[0]['key']).status_code, 200)

    def test_get_not_found(self):
        data = [
            {'key': 'equation', 'value': json.dumps({'12+34': 46})},
        ]
        requests.delete(URL + '/' + data[0]['key'])
        self.assertEqual(requests.get(URL + '/' + data[0]['key']).status_code, 404)

    def test_put_success(self):
        data = [
            {'key': 'equation', 'value': json.dumps({'12+34': 46})},
            {'value': json.dumps({'a': 'b'})},
        ]
        requests.delete(URL + '/' + data[0]['key'])
        self.assertEqual(requests.post(URL, json=data[0]).status_code, 200)
        self.assertEqual(requests.put(URL + '/' + data[0]['key'], json=data[1]).status_code, 200)
        self.assertEqual(requests.delete(URL + '/' + data[0]['key']).status_code, 200)

    def test_put_invalid_data(self):
        data = [
            {'key': 'equation', 'value': json.dumps({'12+34': 46})},
            {'value': 1},
        ]
        requests.delete(URL + '/' + data[0]['key'])
        self.assertEqual(requests.post(URL, json=data[0]).status_code, 200)
        self.assertEqual(requests.put(URL + '/' + data[0]['key'], json=data[1]).status_code, 400)
        self.assertEqual(requests.delete(URL + '/' + data[0]['key']).status_code, 200)

    def test_put_not_found(self):
        data = [
            {'key': 'notFoundKey'},
            {'value': '1'},
        ]
        requests.delete(URL + '/' + data[0]['key'])
        self.assertEqual(requests.put(URL + '/' + data[0]['key'], json=data[1]).status_code, 404)

    def test_delete_not_found(self):
        data = [
            {'key': 'equation'},
        ]
        requests.delete(URL + '/' + data[0]['key'])
        self.assertEqual(requests.delete(URL + '/' + data[0]['key']).status_code, 404)


if __name__ == '__main__':
    unittest.main()
